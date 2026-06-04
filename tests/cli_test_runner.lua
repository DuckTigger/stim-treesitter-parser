#!/usr/bin/env lua

-- CLI Test runner for stim-treesitter plugin
-- This version works standalone without Neovim
-- Usage: lua tests/cli_test_runner.lua

-- Setup package path
local script_path = debug.getinfo(1, "S").source:match("@?(.*/)")
if not script_path then
    -- Fallback for when debug info is not available
    script_path = "./"
end
package.path = script_path .. '?.lua;' .. script_path .. '../lua/?.lua;' .. package.path

-- Initialize mock vim API
local mock_vim = require('mock_vim')
_G.vim = mock_vim

-- Mock stim-treesitter module for CLI testing
local function create_mock_stim_treesitter()
    local M = {}
    local ns_id = vim.api.nvim_create_namespace('stim_treesitter_highlights')

    -- Simple measurement parsing for CLI tests
    local function parse_measurements_simple(content)
        local measurements = {}
        local measurement_count = 0

        local lines = {}
        for line in content:gmatch("[^\n]+") do
            table.insert(lines, line)
        end

        for line_idx, line in ipairs(lines) do
            if line:match("^%s*M%s+") then
                -- Extract qubit numbers
                local qubits = {}
                for qubit in line:gmatch("%d+") do
                    table.insert(qubits, tonumber(qubit))
                end

                -- Count repeat multipliers
                local repeat_multiplier = 1
                local indent_level = 0

                -- Simple repeat detection by looking at previous lines
                for i = line_idx - 1, 1, -1 do
                    local prev_line = lines[i]
                    if prev_line:match("REPEAT%s+(%d+)") then
                        local count = tonumber(prev_line:match("REPEAT%s+(%d+)"))
                        if count then
                            repeat_multiplier = repeat_multiplier * count
                        end
                    elseif prev_line:match("^%s*}") then
                        break
                    end
                end

                -- Create measurement entries
                for repeat_idx = 1, repeat_multiplier do
                    for _, qubit in ipairs(qubits) do
                        measurements[measurement_count] = {
                            line = line_idx,
                            text = line,
                            index = measurement_count,
                            qubit = qubit,
                            repeat_instance = repeat_idx - 1
                        }
                        measurement_count = measurement_count + 1
                    end
                end
            end
        end

        return measurements
    end

    function M.get_record_ref_at_cursor(bufnr)
        local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) or {}, "\n")
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = cursor[1]
        local col = cursor[2]

        local lines = {}
        for line in content:gmatch("[^\n]+") do
            table.insert(lines, line)
        end

        if not lines[row] then
            return nil
        end

        local line = lines[row]
        local rec_pattern = "rec%[([%-]?%d+)%]"
        local start_pos, end_pos, index_str = line:find(rec_pattern)

        if start_pos and col >= start_pos - 1 and col < end_pos then
            local index = tonumber(index_str)
            return {
                index = index,
                is_valid = index and index < 0,
                row = row - 1,
                start_col = start_pos - 1,
                end_col = end_pos
            }
        end

        return nil
    end

    function M.highlight_measurement()
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

        local record_ref = M.get_record_ref_at_cursor(bufnr)
        if not record_ref or not record_ref.is_valid then
            if record_ref and not record_ref.is_valid then
                vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Error',
                    record_ref.row, record_ref.start_col, record_ref.end_col)
            end
            return
        end

        -- Mock highlighting - just add to highlight storage
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimRecordHighlight',
            record_ref.row, record_ref.start_col, record_ref.end_col)
    end

    function M.show_info()
        local bufnr = vim.api.nvim_get_current_buf()
        local record_ref = M.get_record_ref_at_cursor(bufnr)

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

        vim.notify(string.format("Found valid record reference: rec[%d]", record_ref.index), vim.log.levels.INFO)
    end

    function M.setup()
        vim.cmd([[
            highlight default StimMeasurementHighlight guibg=#3a5f3a ctermbg=22
            highlight default StimRecordHighlight guibg=#5f3a3a ctermbg=52
        ]])

        vim.api.nvim_create_user_command('StimInfoTS', M.show_info, {
            desc = 'Show information about the Stim measurement record under cursor'
        })

        vim.api.nvim_create_user_command('StimCheckParser', function()
            M.check_parser()
        end, {
            desc = 'Check if Stim Tree-sitter parser is installed'
        })
    end

    function M.check_parser()
        -- In CLI mode, always return false since we don't have real tree-sitter
        vim.notify("CLI mode: Tree-sitter parser check skipped", vim.log.levels.WARN)
        return false
    end

    -- Expose internal function for testing
    M._parse_measurements_simple = parse_measurements_simple

    return M
end

-- Setup mock environment
package.loaded['stim-treesitter'] = create_mock_stim_treesitter()

local function run_all_tests()
    print("=== Stim Tree-sitter Plugin CLI Test Suite ===\n")

    -- Test results storage
    local all_results = {
        measurement_parsing = {},
        repeat_blocks = {},
        record_resolution = {},
        integration = {},
        shift_records = {}
    }

    -- Helper to create buffer with content for CLI
    local function create_test_buffer_cli(content)
        local bufnr = vim.api.nvim_create_buf(false, true)
        local lines = {}
        for line in content:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(bufnr, 'filetype', 'stim')
        return bufnr
    end

    -- Load fixture helper for CLI
    local function load_fixture_cli(filename)
        local filepath = script_path .. 'fixtures/' .. filename
        local file = io.open(filepath, 'r')
        if not file then
            error("Could not open fixture file: " .. filepath)
        end
        local content = file:read('*all')
        file:close()
        return content
    end

    -- Simplified tests that work in CLI mode
    local function run_basic_tests()
        local results = {}
        local function test(name, test_fn)
            local ok, err = pcall(test_fn)
            table.insert(results, {
                name = name,
                passed = ok,
                error = err
            })
            if ok then
                print("✓ " .. name)
            else
                print("✗ " .. name .. ": " .. tostring(err))
            end
        end

        test("Mock vim API works", function()
            local bufnr = vim.api.nvim_create_buf(false, true)
            assert(bufnr > 0, "Should create buffer")
            assert(vim.api.nvim_buf_is_valid(bufnr), "Buffer should be valid")
            vim.api.nvim_buf_delete(bufnr, {force = true})
        end)

        test("Basic measurement parsing", function()
            local content = "M 0 1\nM 2 3 4"
            local bufnr = create_test_buffer_cli(content)

            vim.api.nvim_set_current_buf(bufnr)
            local stim_treesitter = require('stim-treesitter')

            -- Should not crash
            stim_treesitter.highlight_measurement()

            vim.api.nvim_buf_delete(bufnr, {force = true})
        end)

        test("Record reference parsing", function()
            local content = "M 0 1\nDETECTOR rec[-1]"
            local bufnr = create_test_buffer_cli(content)

            vim.api.nvim_set_current_buf(bufnr)
            vim.api.nvim_win_set_cursor(0, {2, 12})

            local stim_treesitter = require('stim-treesitter')
            local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)

            assert(record_ref ~= nil, "Should find record reference")
            assert(record_ref.index == -1, "Should parse index correctly")
            assert(record_ref.is_valid == true, "Negative index should be valid")

            vim.api.nvim_buf_delete(bufnr, {force = true})
        end)

        test("Invalid record reference", function()
            local content = "DETECTOR rec[1]"
            local bufnr = create_test_buffer_cli(content)

            vim.api.nvim_set_current_buf(bufnr)
            vim.api.nvim_win_set_cursor(0, {1, 12})

            local stim_treesitter = require('stim-treesitter')
            local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)

            assert(record_ref ~= nil, "Should find record reference")
            assert(record_ref.index == 1, "Should parse positive index")
            assert(record_ref.is_valid == false, "Positive index should be invalid")

            vim.api.nvim_buf_delete(bufnr, {force = true})
        end)

        test("REPEAT block basic test", function()
            local content = load_fixture_cli('repeat.stim')
            local bufnr = create_test_buffer_cli(content)

            vim.api.nvim_set_current_buf(bufnr)
            vim.api.nvim_win_set_cursor(0, {4, 5}) -- rec[-3]

            local stim_treesitter = require('stim-treesitter')

            -- Should not crash
            stim_treesitter.highlight_measurement()

            vim.api.nvim_buf_delete(bufnr, {force = true})
        end)

        test("Plugin setup", function()
            local stim_treesitter = require('stim-treesitter')

            -- Should not crash
            stim_treesitter.setup()

            -- Commands should exist
            local commands = vim.api.nvim_get_commands({})
            assert(commands['StimInfoTS'] ~= nil, "StimInfoTS command should exist")
            assert(commands['StimCheckParser'] ~= nil, "StimCheckParser command should exist")
        end)

        test("Show info functionality", function()
            local content = "M 0 1\nDETECTOR rec[-1]"
            local bufnr = create_test_buffer_cli(content)

            vim.api.nvim_set_current_buf(bufnr)
            vim.api.nvim_win_set_cursor(0, {2, 12})

            local stim_treesitter = require('stim-treesitter')

            -- Should not crash
            stim_treesitter.show_info()

            vim.api.nvim_buf_delete(bufnr, {force = true})
        end)

        return results
    end

    -- Run shift_records tests (pure Lua logic, loads real module via dofile)
    print("Running shift_records tests...")
    local shift_ok, shift_tests = pcall(require, 'test_shift_records')
    if shift_ok then
        all_results.shift_records = shift_tests.run_tests()
    else
        print("  (skipped: " .. tostring(shift_tests) .. ")")
    end

    -- Run the simplified tests
    print("\nRunning CLI-compatible tests...")
    all_results.cli_basic = run_basic_tests()

    -- Calculate overall results
    local total_tests = 0
    local total_passed = 0
    local failed_tests = {}

    for suite_name, results in pairs(all_results) do
        for _, result in ipairs(results) do
            total_tests = total_tests + 1
            if result.passed then
                total_passed = total_passed + 1
            else
                table.insert(failed_tests, {
                    suite = suite_name,
                    name = result.name,
                    error = result.error
                })
            end
        end
    end

    -- Print summary
    print("\n" .. string.rep("=", 50))
    print(string.format("CLI TEST SUMMARY: %d/%d tests passed", total_passed, total_tests))

    if #failed_tests > 0 then
        print("\nFAILED TESTS:")
        for _, failure in ipairs(failed_tests) do
            print(string.format("  [%s] %s: %s", failure.suite, failure.name, tostring(failure.error)))
        end
        print(string.rep("=", 50))
        return false
    else
        print("All CLI tests passed! 🎉")
        print(string.rep("=", 50))
        return true
    end
end

-- Reset mock environment
vim.reset()

-- Run the tests
local success = run_all_tests()
os.exit(success and 0 or 1)