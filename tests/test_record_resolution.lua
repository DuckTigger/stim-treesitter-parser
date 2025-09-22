-- Test record reference resolution functionality
local function run_tests()
    local stim_treesitter = require('stim-treesitter')
    local assert = assert
    local results = {}

    -- Helper function to run a test
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

    -- Helper to create a temporary buffer with content
    local function create_test_buffer(content)
        local bufnr = vim.api.nvim_create_buf(false, true)
        local lines = {}
        for line in content:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(bufnr, 'filetype', 'stim')
        return bufnr
    end

    -- Test 1: Basic record reference resolution
    test("Basic record reference resolution", function()
        local content = [[M 0 1 2
DETECTOR rec[-1]
DETECTOR rec[-2]
DETECTOR rec[-3]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)

        -- Test rec[-1] (should point to qubit 2)
        vim.api.nvim_win_set_cursor(0, {2, 12})
        local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[-1]")
        assert(record_ref.index == -1, "Should have correct index")
        assert(record_ref.is_valid == true, "Should be valid")

        -- Test rec[-2] (should point to qubit 1)
        vim.api.nvim_win_set_cursor(0, {3, 12})
        record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[-2]")
        assert(record_ref.index == -2, "Should have correct index")

        -- Test rec[-3] (should point to qubit 0)
        vim.api.nvim_win_set_cursor(0, {4, 12})
        record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[-3]")
        assert(record_ref.index == -3, "Should have correct index")

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Test 2: Record references across multiple measurements
    test("Record references across multiple measurements", function()
        local content = [[M 0
M 1 2
M 3
DETECTOR rec[-1]
DETECTOR rec[-2]
DETECTOR rec[-4]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)

        -- Test each reference
        vim.api.nvim_win_set_cursor(0, {4, 12}) -- rec[-1] -> M 3
        stim_treesitter.highlight_measurement()

        vim.api.nvim_win_set_cursor(0, {5, 12}) -- rec[-2] -> M 2
        stim_treesitter.highlight_measurement()

        vim.api.nvim_win_set_cursor(0, {6, 12}) -- rec[-4] -> M 0
        stim_treesitter.highlight_measurement()

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Test 3: Invalid record references
    test("Invalid positive record references", function()
        local content = [[M 0 1
DETECTOR rec[0]
DETECTOR rec[1]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)

        -- Test rec[0] (invalid)
        vim.api.nvim_win_set_cursor(0, {2, 12})
        local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[0]")
        assert(record_ref.index == 0, "Should parse index")
        assert(record_ref.is_valid == false, "Should be invalid")

        -- Test rec[1] (invalid)
        vim.api.nvim_win_set_cursor(0, {3, 12})
        record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[1]")
        assert(record_ref.index == 1, "Should parse index")
        assert(record_ref.is_valid == false, "Should be invalid")

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Test 4: Out of range record references
    test("Out of range record references", function()
        local content = [[M 0
DETECTOR rec[-5]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_win_set_cursor(0, {2, 12}) -- rec[-5]

        -- Should handle gracefully (may not highlight anything)
        stim_treesitter.highlight_measurement()

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Test 5: Record references with REPEAT blocks
    test("Record references with REPEAT blocks", function()
        local content = [[REPEAT 3 {
   M 0 1
}
DETECTOR rec[-1]
DETECTOR rec[-3]
DETECTOR rec[-6]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)

        -- Test rec[-1] (should point to last measurement)
        vim.api.nvim_win_set_cursor(0, {4, 12})
        local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[-1]")
        stim_treesitter.highlight_measurement()

        -- Test rec[-3] (should point to measurement 3 iterations back)
        vim.api.nvim_win_set_cursor(0, {5, 12})
        record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[-3]")
        stim_treesitter.highlight_measurement()

        -- Test rec[-6] (should point to first measurement)
        vim.api.nvim_win_set_cursor(0, {6, 12})
        record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref ~= nil, "Should find rec[-6]")
        stim_treesitter.highlight_measurement()

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Test 6: Complex nested REPEAT scenario
    test("Complex nested REPEAT record resolution", function()
        local content = [[M 0
REPEAT 2 {
   M 1
   REPEAT 2 {
      M 2 3
   }
   M 4
}
M 5
DETECTOR rec[-1]
DETECTOR rec[-5]
DETECTOR rec[-11]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)

        -- Test each reference
        vim.api.nvim_win_set_cursor(0, {11, 12}) -- rec[-1] -> M 5
        stim_treesitter.highlight_measurement()

        vim.api.nvim_win_set_cursor(0, {12, 12}) -- rec[-5] -> M 4 (second iteration)
        stim_treesitter.highlight_measurement()

        vim.api.nvim_win_set_cursor(0, {13, 13}) -- rec[-11] -> M 0
        stim_treesitter.highlight_measurement()

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Test 7: Edge case - cursor not on record reference
    test("Cursor not on record reference", function()
        local content = [[M 0 1
DETECTOR rec[-1]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_win_set_cursor(0, {1, 0}) -- Position on M

        local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
        assert(record_ref == nil, "Should not find record reference when cursor is not on one")

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Test 8: Show info functionality
    test("Show info functionality", function()
        local content = [[M 0 1 2
DETECTOR rec[-2]]]
        local bufnr = create_test_buffer(content)

        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_win_set_cursor(0, {2, 12}) -- Position on rec[-2]

        -- Should not crash when showing info
        stim_treesitter.show_info()

        vim.api.nvim_buf_delete(bufnr, {force = true})
    end)

    -- Summary
    local passed = 0
    local total = #results
    for _, result in ipairs(results) do
        if result.passed then
            passed = passed + 1
        end
    end

    print(string.format("\n--- Record Resolution Tests ---"))
    print(string.format("Passed: %d/%d", passed, total))

    return results
end

-- Export for external test runner
return {
    run_tests = run_tests
}