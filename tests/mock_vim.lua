-- Mock Neovim API for CLI testing
-- This provides a basic implementation of vim.* functions needed for tests

local mock_vim = {}

-- Mock buffer storage
local buffers = {}
local buffer_counter = 0
local current_buffer = nil
local cursor_pos = {1, 0}

-- Mock namespaces
local namespaces = {}
local namespace_counter = 0

-- Mock highlights
local highlights = {}

-- Mock vim.api functions
mock_vim.api = {}

function mock_vim.api.nvim_create_buf(listed, scratch)
    buffer_counter = buffer_counter + 1
    local bufnr = buffer_counter
    buffers[bufnr] = {
        lines = {},
        options = {},
        valid = true
    }
    return bufnr
end

function mock_vim.api.nvim_buf_set_lines(bufnr, start, end_line, strict_indexing, replacement)
    if not buffers[bufnr] then return end
    local lines = buffers[bufnr].lines or {}
    -- Neovim semantics: start/end_line are 0-indexed, end_line exclusive, -1 = end of buffer
    if end_line == -1 then end_line = #lines end
    local new_lines = {}
    for i = 1, start do
        table.insert(new_lines, lines[i])
    end
    for _, line in ipairs(replacement) do
        table.insert(new_lines, line)
    end
    for i = end_line + 1, #lines do
        table.insert(new_lines, lines[i])
    end
    buffers[bufnr].lines = new_lines
end

function mock_vim.api.nvim_buf_get_lines(bufnr, start, end_line, strict_indexing)
    if not buffers[bufnr] then return {} end
    local lines = buffers[bufnr].lines or {}
    -- Neovim semantics: start/end_line are 0-indexed, end_line exclusive, -1 = end of buffer
    if end_line == -1 then end_line = #lines end
    local result = {}
    for i = start + 1, end_line do
        table.insert(result, lines[i])
    end
    return result
end

function mock_vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, opts)
    if not buffers[bufnr] or not buffers[bufnr].lines[start_row + 1] then
        return {""}
    end
    local line = buffers[bufnr].lines[start_row + 1]
    local text = line:sub(start_col + 1, end_col)
    return {text}
end

function mock_vim.api.nvim_buf_set_option(bufnr, name, value)
    if not buffers[bufnr] then return end
    buffers[bufnr].options[name] = value
end

function mock_vim.api.nvim_buf_delete(bufnr, opts)
    if buffers[bufnr] then
        buffers[bufnr].valid = false
        buffers[bufnr] = nil
    end
end

function mock_vim.api.nvim_buf_is_valid(bufnr)
    return buffers[bufnr] ~= nil and buffers[bufnr].valid == true
end

function mock_vim.api.nvim_get_current_buf()
    return current_buffer or 1
end

function mock_vim.api.nvim_set_current_buf(bufnr)
    current_buffer = bufnr
end

function mock_vim.api.nvim_win_get_cursor(winid)
    return cursor_pos
end

function mock_vim.api.nvim_win_set_cursor(winid, pos)
    cursor_pos = pos
end

function mock_vim.api.nvim_create_namespace(name)
    namespace_counter = namespace_counter + 1
    namespaces[name] = namespace_counter
    return namespace_counter
end

function mock_vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line_start, line_end)
    -- Mock clearing highlights
    if highlights[bufnr] then
        highlights[bufnr][ns_id] = nil
    end
end

function mock_vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, line, col_start, col_end)
    -- Mock adding highlights
    if not highlights[bufnr] then
        highlights[bufnr] = {}
    end
    if not highlights[bufnr][ns_id] then
        highlights[bufnr][ns_id] = {}
    end
    table.insert(highlights[bufnr][ns_id], {
        hl_group = hl_group,
        line = line,
        col_start = col_start,
        col_end = col_end
    })
end

function mock_vim.api.nvim_create_augroup(name, opts)
    return name
end

function mock_vim.api.nvim_create_autocmd(events, opts)
    -- Mock autocmd creation
    return true
end

function mock_vim.api.nvim_create_user_command(name, command, opts)
    -- Mock command creation
    return true
end

function mock_vim.api.nvim_get_commands(opts)
    -- Mock command listing
    return {
        StimInfoTS = {name = "StimInfoTS"},
        StimCheckParser = {name = "StimCheckParser"}
    }
end

-- Mock vim.ui (input prompt)
mock_vim.ui = {}

-- Default: simulate user pressing <Esc> (cancels).
-- Override with mock_vim.set_ui_inputs({...}) for sequential predetermined responses.
function mock_vim.ui.input(opts, callback)
    callback(nil)
end

-- Set up a sequence of predetermined inputs for vim.ui.input calls.
-- Each call to vim.ui.input will consume the next value in the list.
-- nil in the list simulates the user pressing <Esc>.
function mock_vim.set_ui_inputs(inputs)
    local i = 0
    mock_vim.ui.input = function(opts, callback)
        i = i + 1
        callback(inputs[i])
    end
end

-- Mock vim.keymap
mock_vim.keymap = {}
function mock_vim.keymap.set(mode, lhs, rhs, opts) end

-- Mock vim.tbl_extend
function mock_vim.tbl_extend(behaviour, ...)
    local result = {}
    for _, t in ipairs({...}) do
        for k, v in pairs(t) do
            result[k] = v
        end
    end
    return result
end

-- Mock vim.defer_fn
function mock_vim.defer_fn(fn, delay)
    -- In tests run synchronously; don't call fn automatically.
    return { stop = function() end }
end

-- Mock vim.fn functions
mock_vim.fn = {}

function mock_vim.fn.expand(pattern)
    if pattern == '%:p:h' then
        return '/mock/test/path'
    end
    return pattern
end

-- Mock vim.treesitter functions
mock_vim.treesitter = {}

function mock_vim.treesitter.get_parser(bufnr, lang)
    if lang ~= 'stim' then
        return nil
    end

    -- Mock parser with basic functionality
    return {
        parse = function()
            return {{
                root = function()
                    return {
                        -- Mock AST node
                        iter_children = function() return function() end end,
                        range = function() return 0, 0, 0, 0 end,
                        type = function() return "circuit" end,
                        parent = function() return nil end
                    }
                end
            }}
        end
    }
end

mock_vim.treesitter.query = {}

function mock_vim.treesitter.query.parse(lang, query_string)
    if lang ~= 'stim' then
        error("Unsupported language: " .. lang)
    end

    -- Mock query object
    return {
        iter_captures = function(root, bufnr, start_row, end_row)
            return function()
                -- Return empty iterator for mock
                return nil
            end
        end
    }
end

-- Mock vim.loop functions
mock_vim.loop = {}

function mock_vim.loop.hrtime()
    -- Return mock high-resolution time in nanoseconds
    return os.clock() * 1e9
end

-- Mock vim.notify function
function mock_vim.notify(message, level)
    local level_names = {
        [1] = "ERROR",
        [2] = "WARN",
        [3] = "INFO",
        [4] = "DEBUG"
    }
    level = level or 3
    print(string.format("[%s] %s", level_names[level] or "INFO", message))
end

-- Mock vim.log levels
mock_vim.log = {
    levels = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4
    }
}

-- Mock vim.cmd function
function mock_vim.cmd(command)
    -- Mock vim command execution
    return true
end

-- Mock vim.filetype
mock_vim.filetype = {}

function mock_vim.filetype.add(opts)
    -- Mock filetype detection
    return true
end

-- Helper functions for testing
function mock_vim.reset()
    buffers = {}
    buffer_counter = 0
    current_buffer = nil
    cursor_pos = {1, 0}
    namespaces = {}
    namespace_counter = 0
    highlights = {}
    -- Restore ui.input to default (cancel)
    mock_vim.ui.input = function(opts, callback) callback(nil) end
end

function mock_vim.get_buffer_content(bufnr)
    if buffers[bufnr] then
        return buffers[bufnr].lines
    end
    return nil
end

function mock_vim.get_highlights(bufnr, ns_id)
    if highlights[bufnr] and highlights[bufnr][ns_id] then
        return highlights[bufnr][ns_id]
    end
    return {}
end

return mock_vim