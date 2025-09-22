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

-- Setup function
function M.setup()
    -- Define highlight groups
    vim.cmd([[
        highlight default StimMeasurementHighlight guibg=#3a5f3a ctermbg=22
        highlight default StimRecordHighlight guibg=#5f3a3a ctermbg=52
    ]])
    
    -- Setup autocmds for cursor movement
    local group = vim.api.nvim_create_augroup('StimTreesitter', { clear = true })
    
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = group,
        pattern = '*.stim',
        callback = function()
            -- Check if buffer is valid
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

-- Export the get_record_ref_at_cursor function for external use
M.get_record_ref_at_cursor = get_record_ref_at_cursor

return M

