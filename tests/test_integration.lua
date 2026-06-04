-- Integration tests for the full stim-treesitter plugin
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

	-- Helper to load fixture file
	local function load_fixture(filename)
		local filepath = vim.fn.expand("%:p:h") .. "/fixtures/" .. filename
		local file = io.open(filepath, "r")
		if not file then
			error("Could not open fixture file: " .. filepath)
		end
		local content = file:read("*all")
		file:close()
		return content
	end

	-- Helper to create a buffer from fixture
	local function create_fixture_buffer(filename)
		local content = load_fixture(filename)
		local bufnr = vim.api.nvim_create_buf(false, true)
		local lines = {}
		for line in content:gmatch("[^\n]*") do
			table.insert(lines, line)
		end
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(bufnr, "filetype", "stim")
		return bufnr
	end

	-- Test 1: Full workflow with simple.stim fixture
	test("Full workflow with simple.stim", function()
		local bufnr = create_fixture_buffer("simple.stim")
		vim.api.nvim_set_current_buf(bufnr)

		-- Test highlighting on each detector line
		vim.api.nvim_win_set_cursor(0, { 2, 12 }) -- rec[-1]
		stim_treesitter.highlight_measurement()

		vim.api.nvim_win_set_cursor(0, { 4, 12 }) -- rec[-2]
		stim_treesitter.highlight_measurement()

		vim.api.nvim_win_set_cursor(0, { 5, 12 }) -- rec[-1]
		stim_treesitter.highlight_measurement()

		-- Test show info
		stim_treesitter.show_info()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 2: Full workflow with repeat.stim fixture
	test("Full workflow with repeat.stim", function()
		local bufnr = create_fixture_buffer("repeat.stim")
		vim.api.nvim_set_current_buf(bufnr)

		-- Test highlighting on record references
		vim.api.nvim_win_set_cursor(0, { 4, 5 }) -- rec[-3]
		stim_treesitter.highlight_measurement()

		vim.api.nvim_win_set_cursor(0, { 8, 12 }) -- rec[-1] in detector
		stim_treesitter.highlight_measurement()

		-- Test show info
		stim_treesitter.show_info()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 3: Full workflow with nested_repeat.stim fixture
	test("Full workflow with nested_repeat.stim", function()
		local bufnr = create_fixture_buffer("nested_repeat.stim")
		vim.api.nvim_set_current_buf(bufnr)

		-- Test highlighting
		vim.api.nvim_win_set_cursor(0, { 8, 5 }) -- rec[-10]
		stim_treesitter.highlight_measurement()

		-- Test show info
		stim_treesitter.show_info()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 4: Plugin setup and commands
	test("Plugin setup and commands", function()
		-- Test setup (should not error)
		stim_treesitter.setup()

		-- Test check parser command exists
		local commands = vim.api.nvim_get_commands({})
		assert(commands["StimInfoTS"] ~= nil, "StimInfoTS command should exist")
		assert(commands["StimCheckParser"] ~= nil, "StimCheckParser command should exist")

		-- Test check parser function
		local parser_ok = stim_treesitter.check_parser()
		-- Should return boolean (may be false if parser not installed)
		assert(type(parser_ok) == "boolean", "check_parser should return boolean")
	end)

	-- Test 5: Highlighting persistence
	test("Highlighting persistence across cursor movements", function()
		local content = [[M 0 1
M 2 3
DETECTOR rec[-1]
DETECTOR rec[-3]
]]
		local bufnr = vim.api.nvim_create_buf(false, true)
		local lines = {}
		for line in content:gmatch("[^\n]+") do
			table.insert(lines, line)
		end
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(bufnr, "filetype", "stim")
		vim.api.nvim_set_current_buf(bufnr)

		-- Move to first detector
		vim.api.nvim_win_set_cursor(0, { 3, 12 }) -- rec[-1]
		stim_treesitter.highlight_measurement()

		-- Move to second detector
		vim.api.nvim_win_set_cursor(0, { 4, 12 }) -- rec[-3]
		stim_treesitter.highlight_measurement()

		-- Move away and back
		vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- M 0 1
		stim_treesitter.highlight_measurement() -- Should clear highlights

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 6: Error handling with malformed input
	test("Error handling with malformed input", function()
		local content = [[M 0 1
DETECTOR rec[-1
DETECTOR rec[abc]
rec]]
		local bufnr = vim.api.nvim_create_buf(false, true)
		local lines = {}
		for line in content:gmatch("[^\n]+") do
			table.insert(lines, line)
		end
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(bufnr, "filetype", "stim")
		vim.api.nvim_set_current_buf(bufnr)

		-- Should handle malformed input gracefully
		vim.api.nvim_win_set_cursor(0, { 2, 12 }) -- malformed rec[-1
		stim_treesitter.highlight_measurement()

		vim.api.nvim_win_set_cursor(0, { 3, 12 }) -- malformed rec[abc]
		stim_treesitter.highlight_measurement()

		vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- incomplete rec
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 7: Performance with large file
	test("Performance with larger circuit", function()
		-- Create a larger circuit programmatically
		local lines = {}
		for i = 1, 100 do
			table.insert(lines, string.format("M %d %d", i * 2, i * 2 + 1))
		end
		table.insert(lines, "DETECTOR rec[-1]")
		table.insert(lines, "DETECTOR rec[-50]")
		table.insert(lines, "DETECTOR rec[-200]")

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(bufnr, "filetype", "stim")
		vim.api.nvim_set_current_buf(bufnr)

		-- Test highlighting performance
		local start_time = vim.loop.hrtime()

		vim.api.nvim_win_set_cursor(0, { 101, 12 }) -- rec[-1]
		stim_treesitter.highlight_measurement()

		vim.api.nvim_win_set_cursor(0, { 102, 12 }) -- rec[-50]
		stim_treesitter.highlight_measurement()

		local end_time = vim.loop.hrtime()
		local duration_ms = (end_time - start_time) / 1e6

		-- Should complete in reasonable time (less than 100ms)
		assert(duration_ms < 100, string.format("Highlighting took too long: %.2fms", duration_ms))

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 8: Multiple buffers
	test("Multiple buffer handling", function()
		local content1 = [[M 0
DETECTOR rec[-1]
]]

		local content2 = [[M 1 2
DETECTOR rec[-2]
]]

		local bufnr1 = vim.api.nvim_create_buf(false, true)
		local bufnr2 = vim.api.nvim_create_buf(false, true)

		-- Setup first buffer
		local lines1 = {}
		for line in content1:gmatch("[^\n]+") do
			table.insert(lines1, line)
		end
		vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, lines1)
		vim.api.nvim_buf_set_option(bufnr1, "filetype", "stim")

		-- Setup second buffer
		local lines2 = {}
		for line in content2:gmatch("[^\n]+") do
			table.insert(lines2, line)
		end
		vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, lines2)
		vim.api.nvim_buf_set_option(bufnr2, "filetype", "stim")

		-- Test switching between buffers
		vim.api.nvim_set_current_buf(bufnr1)
		vim.api.nvim_win_set_cursor(0, { 2, 12 })
		stim_treesitter.highlight_measurement()

		vim.api.nvim_set_current_buf(bufnr2)
		vim.api.nvim_win_set_cursor(0, { 2, 12 })
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr1, { force = true })
		vim.api.nvim_buf_delete(bufnr2, { force = true })
	end)

	-- Summary
	local passed = 0
	local total = #results
	for _, result in ipairs(results) do
		if result.passed then
			passed = passed + 1
		end
	end

	print(string.format("\n--- Integration Tests ---"))
	print(string.format("Passed: %d/%d", passed, total))

	return results
end

-- Export for external test runner
return {
	run_tests = run_tests,
}
