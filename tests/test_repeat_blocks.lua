-- Test REPEAT block handling functionality
local function run_tests()
	local stim_treesitter = require("stim-treesitter")
	local assert = assert
	local results = {}

	-- Helper function to run a test
	local function test(name, test_fn)
		local ok, err = pcall(test_fn)
		table.insert(results, {
			name = name,
			passed = ok,
			error = err,
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
		vim.api.nvim_buf_set_option(bufnr, "filetype", "stim")
		return bufnr
	end

	-- Test 1: Simple REPEAT block
	test("Simple REPEAT block measurement counting", function()
		local content = [[REPEAT 3 {
   M 0 1
}
rec[-3]
]]
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 4, 5 }) -- Position on rec[-3]

		-- Test that we can find the record reference
		local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil, "Should find record reference")
		assert(record_ref.index == -3, "Should parse index correctly")

		-- Test highlighting doesn't crash
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 2: Multiple REPEAT blocks
	test("Multiple REPEAT blocks", function()
		local content = [[REPEAT 2 {
   M 0
}
REPEAT 3 {
   M 1 2
}
rec[-4]
]]
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 7, 5 }) -- Position on rec[-4]

		local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil, "Should find record reference")
		assert(record_ref.index == -4, "Should parse index correctly")

		-- Should be able to highlight without error
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 3: Nested REPEAT blocks
	test("Nested REPEAT blocks", function()
		local content = [[REPEAT 2 {
   M 0
   REPEAT 3 {
      M 1 2
   }
   M 3
}
rec[-10]
]]
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 8, 6 }) -- Position on rec[-10]

		local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil, "Should find record reference")
		assert(record_ref.index == -10, "Should parse index correctly")

		-- Should handle nested repeats without error
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 4: REPEAT with different repeat counts
	test("REPEAT with various counts", function()
		local content = [[REPEAT 1 {
   M 0
}
REPEAT 5 {
   M 1
}
rec[-6]
]]
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 7, 5 }) -- Position on rec[-6]

		local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil, "Should find record reference")

		-- Should not crash with different repeat counts
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 5: REPEAT block with measurements before and after
	test("REPEAT block with surrounding measurements", function()
		local content = [[M 0 1
REPEAT 2 {
   M 2 3
}
M 4
rec[-1]
rec[-3]
rec[-6]
]]
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)

		-- Test rec[-1] (should point to M 4)
		vim.api.nvim_win_set_cursor(0, { 6, 5 })
		local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil and record_ref.index == -1, "Should find rec[-1]")
		stim_treesitter.highlight_measurement()

		-- Test rec[-3] (should point to M 3 from second iteration)
		vim.api.nvim_win_set_cursor(0, { 7, 5 })
		record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil and record_ref.index == -3, "Should find rec[-3]")
		stim_treesitter.highlight_measurement()

		-- Test rec[-6] (should point to M 1 from first measurement)
		vim.api.nvim_win_set_cursor(0, { 8, 5 })
		record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil and record_ref.index == -6, "Should find rec[-6]")
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 6: Empty REPEAT block (edge case)
	test("REPEAT block with no measurements", function()
		local content = [[REPEAT 3 {
}
M 0
rec[-1]
]]
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 4, 5 }) -- Position on rec[-1]

		-- Should handle empty repeat blocks gracefully
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Summary
	local passed = 0
	local total = #results
	for _, result in ipairs(results) do
		if result.passed then
			passed = passed + 1
		end
	end

	print(string.format("\n--- REPEAT Block Tests ---"))
	print(string.format("Passed: %d/%d", passed, total))

	return results
end

-- Export for external test runner
return {
	run_tests = run_tests,
}
