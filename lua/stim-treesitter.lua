-- ~/.config/nvim/lua/stim-treesitter.lua
-- Tree-sitter based Stim Circuit Reader Plugin for Neovim
-- This version uses the correct Tree-sitter API

local M = {}
local ns_id = vim.api.nvim_create_namespace('stim_treesitter_highlights')

-- Helper function to find repeat count for a node
local function get_repeat_multiplier(node, bufnr, root)
    local current = node
    local multiplier = 1

    -- Walk up the tree to find any REPEAT blocks that contain this measurement
    while current do
        current = current:parent()
        if current and current:type() == 'repeat_instruction' then
            -- Find the repeat count in the REPEAT instruction
            for child in current:iter_children() do
                if child:type() == 'integer' then
                    local start_row, start_col, end_row, end_col = child:range()
                    local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
                    local count = tonumber(text[1] or "1")
                    if count then
                        multiplier = multiplier * count
                    end
                    break
                end
            end
        end
    end

    return multiplier
end

-- Parse measurements using Tree-sitter
local function parse_measurements_ts(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then
        return {}
    end

    local tree = parser:parse()[1]
    if not tree then
        return {}
    end

    local root = tree:root()

    local measurements = {}
    local measurement_count = 0

    -- Query for measurement instructions
    local query_string = [[
        (measurement_instruction) @measurement
    ]]

    local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
    if not ok then
        return {}
    end

    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local start_row, start_col, end_row, end_col = node:range()
        local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
        text = text[1] or ""

        -- Extract individual target qubits with their positions
        local targets = {}
        for child in node:iter_children() do
            if child:type() == 'target' then
                local target_start_row, target_start_col, target_end_row, target_end_col = child:range()
                local target_text = vim.api.nvim_buf_get_text(bufnr, target_start_row, target_start_col, target_end_row, target_end_col, {})
                table.insert(targets, {
                    text = target_text[1] or "",
                    start_row = target_start_row,
                    start_col = target_start_col,
                    end_row = target_end_row,
                    end_col = target_end_col
                })
            end
        end

        -- If no explicit targets found, try to parse from the text
        if #targets == 0 then
            -- Simple fallback: split by spaces and look for numbers
            local parts = {}
            for word in text:gmatch("%S+") do
                table.insert(parts, word)
            end

            -- Skip the instruction name (first part) and extract qubit numbers
            for i = 2, #parts do
                if parts[i]:match("^%d+$") then
                    -- Calculate approximate position of this qubit in the line
                    local pos_in_line = text:find(parts[i], 1, true)
                    if pos_in_line then
                        table.insert(targets, {
                            text = parts[i],
                            start_row = start_row,
                            start_col = start_col + pos_in_line - 1,
                            end_row = start_row,
                            end_col = start_col + pos_in_line - 1 + #parts[i]
                        })
                    end
                end
            end
        end

        -- Get the repeat multiplier for this measurement
        local repeat_multiplier = get_repeat_multiplier(node, bufnr, root)

        -- Store each measurement target individually, accounting for repeats
        for repeat_idx = 1, repeat_multiplier do
            for target_idx, target in ipairs(targets) do
                measurements[measurement_count] = {
                    line = start_row + 1,  -- Convert to 1-indexed
                    node = node,
                    text = text,
                    index = measurement_count,
                    target = target,
                    target_index = target_idx - 1,  -- 0-indexed for the target within this measurement
                    repeat_instance = repeat_idx - 1  -- Which repeat iteration this is
                }
                measurement_count = measurement_count + 1
            end
        end

        -- If no targets found at all, create measurement entries for each repeat
        if #targets == 0 then
            for repeat_idx = 1, repeat_multiplier do
                measurements[measurement_count] = {
                    line = start_row + 1,
                    node = node,
                    text = text,
                    index = measurement_count,
                    target = nil,
                    target_index = 0,
                    repeat_instance = repeat_idx - 1
                }
                measurement_count = measurement_count + 1
            end
        end
    end

    return measurements
end

-- Find record reference at cursor position
local function get_record_ref_at_cursor(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1  -- Convert to 0-indexed
    local col = cursor[2]
    
    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then
        return nil
    end
    
    local tree = parser:parse()[1]
    if not tree then
        return nil
    end
    
    local root = tree:root()
    
    -- Query for record references
    local query_string = [[
        (record_ref) @ref
    ]]
    
    local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
    if not ok then
        return nil
    end
    
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local start_row, start_col, end_row, end_col = node:range()
        
        -- Check if cursor is within this node
        if row >= start_row and row <= end_row then
            if row > start_row or col >= start_col then
                if row < end_row or col < end_col then
                    -- Extract the index value
                    local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
                    text = text[1] or ""
                    local index = tonumber(text:match("rec%[([%-]?%d+)%]"))
                    
                    -- Check if it's valid (only negative indices are valid in Stim)
                    local is_valid = index and index < 0
                    
                    return {
                        node = node,
                        index = index,
                        row = start_row,
                        start_col = start_col,
                        end_col = end_col,
                        is_valid = is_valid
                    }
                end
            end
        end
    end
    
    return nil
end

-- Calculate which measurement a record reference points to
local function resolve_measurement_index(rec_index, measurements_up_to_line)
    -- In Stim, only negative indices are valid
    if not rec_index or rec_index >= 0 then
        return nil
    end
    
    -- rec[-1] is the most recent measurement
    return measurements_up_to_line + rec_index
end

-- Highlight measurement from record reference
function M.highlight_measurement()
    local bufnr = vim.api.nvim_get_current_buf()
    
    -- Clear previous highlights
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    
    local record_ref = get_record_ref_at_cursor(bufnr)
    if not record_ref then
        return
    end
    
    if not record_ref.is_valid then
        -- Highlight invalid positive index as error
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Error',
            record_ref.row, record_ref.start_col, record_ref.end_col)
        return
    end
    
    -- Parse all measurements
    local measurements = parse_measurements_ts(bufnr)
    
    -- Count measurements up to the line with the record reference
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local measurements_before = 0
    for idx, measurement in pairs(measurements) do
        if measurement.line <= cursor_line then
            measurements_before = measurements_before + 1
        end
    end
    
    -- Resolve the measurement index
    local target_index = resolve_measurement_index(record_ref.index, measurements_before)
    
    if target_index and target_index >= 0 then
        -- Find and highlight the corresponding measurement target
        for idx, measurement in pairs(measurements) do
            if idx == target_index then
                if measurement.target then
                    -- Highlight only the specific qubit/target
                    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimMeasurementHighlight',
                        measurement.target.start_row, measurement.target.start_col, measurement.target.end_col)
                else
                    -- Fallback to highlighting the entire line if no target info available
                    local start_row, _, end_row, _ = measurement.node:range()
                    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimMeasurementHighlight',
                        start_row, 0, -1)
                end
                break
            end
        end
    end
    
    -- Highlight the record reference itself
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimRecordHighlight',
        record_ref.row, record_ref.start_col, record_ref.end_col)
end

-- Show information about measurement at cursor
function M.show_info()
    local bufnr = vim.api.nvim_get_current_buf()
    local record_ref = get_record_ref_at_cursor(bufnr)
    
    if not record_ref then
        vim.notify("No record reference under cursor", vim.log.levels.INFO)
        return
    end
    
    if not record_ref.is_valid then
        vim.notify(string.format(
            "Invalid record reference rec[%d]: positive indices are not valid in Stim",
            record_ref.index or 0
        ), vim.log.levels.ERROR)
        return
    end
    
    local measurements = parse_measurements_ts(bufnr)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local measurements_before = 0
    
    for idx, measurement in pairs(measurements) do
        if measurement.line <= cursor_line then
            measurements_before = measurements_before + 1
        end
    end
    
    local target_index = resolve_measurement_index(record_ref.index, measurements_before)
    
    if target_index and target_index >= 0 then
        for idx, measurement in pairs(measurements) do
            if idx == target_index then
                vim.notify(string.format(
                    "rec[%d] → Measurement #%d at line %d: %s",
                    record_ref.index, idx, measurement.line, measurement.text
                ), vim.log.levels.INFO)
                return
            end
        end
    end
    
    vim.notify(string.format(
        "rec[%d] points to a measurement that doesn't exist (would be index %d)",
        record_ref.index, target_index or -1
    ), vim.log.levels.WARN)
end

-- Count the number of measurement targets on a single line.
-- Handles M, MX, MY, MZ, MPP (with optional error-param like MZ(0.001)).
-- For MX/MY/MZ/M each space-separated token is one measurement;
-- for MPP each space-separated Pauli-product term is one measurement.
local function count_measurement_targets(line)
    local gate = line:match('^%s*(%u+)')
    if not gate then return 0 end
    local valid = { M = true, MX = true, MY = true, MZ = true, MPP = true }
    if not valid[gate] then return 0 end
    -- Skip optional parameter group e.g. (0.001), then collect remaining tokens
    local rest = line:match('^%s*%u+%b()%s+(.*)') or line:match('^%s*%u+%s+(.*)')
    if not rest then return 0 end
    local count = 0
    for _ in rest:gmatch('%S+') do count = count + 1 end
    return count
end

-- Compute the default threshold for StimShiftRecords given a visual selection.
-- Returns (n_measurements, n_detectors):
--   n_measurements = targets between the previous DETECTOR group and the first
--                    DETECTOR in the selection (exclusive on both ends).
--   n_detectors    = number of DETECTOR lines in the selection.
-- Returns (nil, nil) if no DETECTOR is found in the selection.
local function calculate_threshold_default(bufnr, line1, line2)
    local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    -- all_lines[i] is buffer line i (1-indexed Lua array)

    local first_det = nil
    for i = line1, line2 do
        if all_lines[i] and all_lines[i]:match('^%s*DETECTOR') then
            first_det = i
            break
        end
    end
    if not first_det then return nil, nil end

    local n_det = 0
    for i = line1, line2 do
        if all_lines[i] and all_lines[i]:match('^%s*DETECTOR') then
            n_det = n_det + 1
        end
    end

    -- Walk backwards to find the nearest DETECTOR before the selection
    local prev_det = nil
    for i = first_det - 1, 1, -1 do
        if all_lines[i] and all_lines[i]:match('^%s*DETECTOR') then
            prev_det = i
            break
        end
    end

    local scan_from = prev_det and (prev_det + 1) or 1
    local n_meas = 0
    for i = scan_from, first_det - 1 do
        if all_lines[i] then
            n_meas = n_meas + count_measurement_targets(all_lines[i])
        end
    end

    return n_meas, n_det
end

-- Shift rec[N] indices in the selected range.
-- Records with index < threshold are shifted by subtracting shift_amount.
-- Equivalent to the Vim command:
--   :'<,'>s/\vrec\[(-?\d+)\]/\=submatch(1)<threshold ? 'rec['.(submatch(1)-shift).']' : submatch(0)/g
-- When no threshold is entered, defaults to -(number of DETECTORs in selection),
-- cross-checked against the measurement count between detector groups.
function M.shift_records(line1, line2)
    local bufnr = vim.api.nvim_get_current_buf()
    local n_meas, n_det = calculate_threshold_default(bufnr, line1, line2)

    local default_threshold = nil
    local threshold_prompt
    if n_meas ~= nil and n_det ~= nil then
        -- Use detector count as authoritative; warn if it disagrees with measurement count
        default_threshold = -n_det
        if n_meas ~= n_det then
            threshold_prompt = string.format(
                'Threshold [WARNING: %d measurements ≠ %d detectors; using -%d]: ',
                n_meas, n_det, n_det
            )
        else
            threshold_prompt = string.format(
                'Threshold [default -%d (%d measurements = %d detectors)]: ',
                n_det, n_meas, n_det
            )
        end
    else
        threshold_prompt = 'Threshold (shift records with index < this, e.g. -16): '
    end

    vim.ui.input(
        { prompt = threshold_prompt, default = default_threshold and tostring(default_threshold) or '' },
        function(threshold_str)
            if threshold_str == nil then return end  -- user cancelled with <Esc>
            local threshold
            if threshold_str == '' then
                threshold = default_threshold
            else
                threshold = tonumber(threshold_str)
            end
            if not threshold then
                vim.notify('StimShiftRecords: invalid threshold', vim.log.levels.ERROR)
                return
            end

            vim.ui.input(
                { prompt = 'Shift amount (subtracted from index, e.g. 2): ' },
                function(shift_str)
                    if not shift_str or shift_str == '' then return end
                    local shift = tonumber(shift_str)
                    if not shift then
                        vim.notify('StimShiftRecords: invalid shift amount', vim.log.levels.ERROR)
                        return
                    end

                    local changed = M._apply_shift(bufnr, line1, line2, threshold, shift)

                    if changed > 0 then
                        vim.notify(string.format(
                            'StimShiftRecords: shifted %d record(s) (threshold=%d, shift=%d)',
                            changed, threshold, shift
                        ), vim.log.levels.INFO)
                    else
                        vim.notify('StimShiftRecords: no records matched', vim.log.levels.INFO)
                    end
                end
            )
        end
    )
end

-- Non-interactive core: applies threshold/shift to lines [line1,line2] in bufnr.
-- Returns the number of rec[] tokens that were changed.
function M._apply_shift(bufnr, line1, line2, threshold, shift)
    local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
    local changed = 0
    for i, line in ipairs(lines) do
        if not line:match('^%s*#') then
            lines[i] = line:gsub('rec%[(-?%d+)%]', function(idx_str)
                local idx = tonumber(idx_str)
                if idx and idx < threshold then
                    changed = changed + 1
                    return 'rec[' .. (idx - shift) .. ']'
                end
                return 'rec[' .. idx_str .. ']'
            end)
        end
    end
    vim.api.nvim_buf_set_lines(bufnr, line1 - 1, line2, false, lines)
    return changed
end

-- Expose pure helpers for testing
M._count_measurement_targets  = count_measurement_targets
M._calculate_threshold_default = calculate_threshold_default

-- Setup function
function M.setup()
    -- Define highlight groups
    vim.cmd([[
        highlight default StimMeasurementHighlight guibg=#3a5f3a ctermbg=22
        highlight default StimRecordHighlight guibg=#5f3a3a ctermbg=52
    ]])
    
    -- Setup autocmds for cursor movement with debouncing
    local group = vim.api.nvim_create_augroup('StimTreesitter', { clear = true })
    local highlight_timer = nil

    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = group,
        pattern = '*.stim',
        callback = function()
            -- Cancel previous timer
            if highlight_timer then
                highlight_timer:stop()
            end

            -- Debounce cursor movement highlighting (100ms delay)
            highlight_timer = vim.defer_fn(function()
                local bufnr = vim.api.nvim_get_current_buf()
                if not vim.api.nvim_buf_is_valid(bufnr) then
                    return
                end

                -- Only run if we have the stim parser
                local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'stim')
                if ok and parser then
                    -- Wrap in pcall to prevent errors from breaking cursor movement
                    pcall(M.highlight_measurement)
                end
            end, 100) -- 100ms delay
        end
    })
    
    -- Create commands
    vim.api.nvim_create_user_command('StimInfoTS', M.show_info, {
        desc = 'Show information about the Stim measurement record under cursor'
    })

    vim.api.nvim_create_user_command('StimCheckParser', function()
        M.check_parser()
    end, {
        desc = 'Check if Stim Tree-sitter parser is installed'
    })

    vim.api.nvim_create_user_command('StimQubitCoords', M.show_qubit_coords, {
        desc = 'Show coordinates for the qubit number under cursor'
    })

    vim.api.nvim_create_user_command('StimShiftRecords', function(opts)
        M.shift_records(opts.line1, opts.line2)
    end, {
        range = true,
        desc = 'Shift rec[] indices in the visual selection by a given amount'
    })


    -- Set up key mappings for .stim files
    vim.api.nvim_create_autocmd('FileType', {
        group = group,
        pattern = 'stim',
        callback = function(args)
            local opts = { buffer = args.buf, silent = true }

            -- <leader>sq - Show qubit coordinates
            vim.keymap.set('n', '<leader>sq', M.show_qubit_coords,
                vim.tbl_extend('force', opts, { desc = 'Show qubit coordinates' }))

            -- <leader>sr - Shift rec[] indices in visual selection
            vim.keymap.set('v', '<leader>sr', ":'<,'>StimShiftRecords<CR>",
                vim.tbl_extend('force', opts, { desc = 'Shift measurement record indices' }))
        end
    })
end

-- Function to check if Tree-sitter parser is available
function M.check_parser()
    local bufnr = vim.api.nvim_get_current_buf()
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'stim')
    
    if not ok then
        vim.notify([[
Tree-sitter parser for Stim not found!
Please install it first:
1. Build the grammar (see setup instructions)
2. Register it with nvim-treesitter
3. Run :TSInstall stim
        ]], vim.log.levels.WARN)
        return false
    end
    
    vim.notify("Stim Tree-sitter parser is installed and working!", vim.log.levels.INFO)
    return true
end

-- Parse QUBIT_COORDS definitions from the buffer
local function parse_qubit_coords(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then
        return {}
    end

    local tree = parser:parse()[1]
    if not tree then
        return {}
    end

    local root = tree:root()
    local coords_map = {}

    -- Query for qubit_coords instructions
    local query_string = [[
        (qubit_coords) @coords_inst
    ]]

    local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
    if not ok then
        return {}
    end

    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local coords_node = nil
        local qubit_node = nil

        -- Find the coords and integer children
        for child in node:iter_children() do
            if child:type() == 'coords' then
                coords_node = child
            elseif child:type() == 'integer' then
                qubit_node = child
            end
        end

        if coords_node and qubit_node then
            -- Extract coordinates
            local coords_start_row, coords_start_col, coords_end_row, coords_end_col = coords_node:range()
            local coords_text = vim.api.nvim_buf_get_text(bufnr, coords_start_row, coords_start_col, coords_end_row, coords_end_col, {})

            -- Extract qubit number
            local qubit_start_row, qubit_start_col, qubit_end_row, qubit_end_col = qubit_node:range()
            local qubit_text = vim.api.nvim_buf_get_text(bufnr, qubit_start_row, qubit_start_col, qubit_end_row, qubit_end_col, {})

            local qubit_num = tonumber(qubit_text[1] or "")
            if qubit_num then
                coords_map[qubit_num] = coords_text[1] or ""
            end
        end
    end

    return coords_map
end

-- Find qubit number at cursor position
local function get_qubit_at_cursor(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1  -- Convert to 0-indexed
    local col = cursor[2]

    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then
        return nil
    end

    local tree = parser:parse()[1]
    if not tree then
        return nil
    end

    local root = tree:root()

    -- Query for integer nodes (potential qubit numbers)
    local query_string = [[
        (integer) @int
    ]]

    local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
    if not ok then
        return nil
    end

    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local start_row, start_col, end_row, end_col = node:range()

        -- Check if cursor is within this node
        if row >= start_row and row <= end_row then
            if row > start_row or col >= start_col then
                if row < end_row or col < end_col then
                    -- Check if this integer is used as a qubit target (not in QUBIT_COORDS definition)
                    local parent = node:parent()
                    if parent and parent:type() ~= 'qubit_coords' and parent:type() ~= 'repeat_instruction' then
                        -- Extract the integer value
                        local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
                        local qubit_num = tonumber(text[1] or "")

                        if qubit_num then
                            return {
                                node = node,
                                qubit_num = qubit_num,
                                row = start_row,
                                start_col = start_col,
                                end_col = end_col
                            }
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- Show qubit coordinates in floating window
function M.show_qubit_coords()
    local bufnr = vim.api.nvim_get_current_buf()

    -- First check if we're in a .stim file
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if not filename:match('%.stim$') then
        local lines = { "Not in a .stim file" }
        M._show_coord_float(lines)
        return
    end

    -- Check if cursor is on an integer at all
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local line_text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

    -- Get character under cursor
    local char_under_cursor = line_text:sub(col + 1, col + 1)
    if not char_under_cursor:match('%d') then
        local lines = { "Cursor not on a number" }
        M._show_coord_float(lines)
        return
    end

    local qubit_info = get_qubit_at_cursor(bufnr)
    if not qubit_info then
        -- Check if we're in a QUBIT_COORDS definition
        local parser = vim.treesitter.get_parser(bufnr, 'stim')
        if parser then
            local tree = parser:parse()[1]
            if tree then
                local root = tree:root()
                local query_string = [[(qubit_coords) @coords]]
                local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
                if ok then
                    for id, node in query:iter_captures(root, bufnr, 0, -1) do
                        local start_row, start_col, end_row, end_col = node:range()
                        if row >= start_row and row <= end_row and
                           (row > start_row or col >= start_col) and
                           (row < end_row or col < end_col) then
                            local lines = { "Cursor in QUBIT_COORDS definition", "Use on qubit references instead" }
                            M._show_coord_float(lines)
                            return
                        end
                    end
                end
            end
        end

        -- Check if it's a number in REPEAT instruction
        if parser then
            local tree = parser:parse()[1]
            if tree then
                local root = tree:root()
                local query_string = [[(repeat_instruction) @repeat]]
                local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
                if ok then
                    for id, node in query:iter_captures(root, bufnr, 0, -1) do
                        local start_row, start_col, end_row, end_col = node:range()
                        if row >= start_row and row <= end_row and
                           (row > start_row or col >= start_col) and
                           (row < end_row or col < end_col) then
                            local lines = { "Cursor on repeat count", "Use on qubit numbers instead" }
                            M._show_coord_float(lines)
                            return
                        end
                    end
                end
            end
        end

        local lines = { "Number under cursor is not a qubit reference" }
        M._show_coord_float(lines)
        return
    end

    local coords_map = parse_qubit_coords(bufnr)

    -- Check if any coordinates are defined at all
    local coords_count = 0
    for _ in pairs(coords_map) do
        coords_count = coords_count + 1
    end

    if coords_count == 0 then
        local lines = {
            string.format("Qubit %d", qubit_info.qubit_num),
            "No QUBIT_COORDS defined in file"
        }
        M._show_coord_float(lines)
        return
    end

    local coords = coords_map[qubit_info.qubit_num]

    local lines
    if coords then
        lines = {
            string.format("Qubit %d coordinates:", qubit_info.qubit_num),
            coords
        }
    else
        lines = {
            string.format("Qubit %d", qubit_info.qubit_num),
            "No coordinates defined for this qubit"
        }
    end

    M._show_coord_float(lines)
end

-- Helper function to show coordinate floating window
function M._show_coord_float(lines)
    local bufnr = vim.api.nvim_get_current_buf()

    -- Create floating window
    local float_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(float_bufnr, 0, -1, false, lines)

    -- Calculate window size based on content
    local max_width = 0
    for _, line in ipairs(lines) do
        max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
    end

    local win_opts = {
        relative = "cursor",
        width = math.min(max_width + 4, 80),
        height = #lines,
        row = 1,
        col = 0,
        border = "rounded",
        style = "minimal",
        zindex = 50,
    }

    local win_id = vim.api.nvim_open_win(float_bufnr, false, win_opts)

    -- Set highlight
    vim.api.nvim_win_set_option(win_id, 'winhl', 'Normal:Normal,FloatBorder:FloatBorder')

    -- Auto-close on cursor movement
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter" }, {
        buffer = bufnr,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(win_id) then
                vim.api.nvim_win_close(win_id, true)
            end
        end,
    })
end


-- Export the get_record_ref_at_cursor function for external use
M.get_record_ref_at_cursor = get_record_ref_at_cursor

return M

