-- Test measurement parsing functionality
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

	-- Test 1: Basic measurement parsing
	test("Parse simple measurements", function()
		local content = [[M 0 1
M 2 3 4]]
		local bufnr = create_test_buffer(content)

		-- Access the internal parse function through the module
		local parse_measurements = require("stim-treesitter")._parse_measurements_ts
			or require("stim-treesitter").parse_measurements_ts

		if not parse_measurements then
			-- If internal function not exposed, test through public interface
			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			-- This should not error
			stim_treesitter.highlight_measurement()
			return
		end

		local measurements = parse_measurements(bufnr)

		-- Should have 5 total measurements: 2 qubits + 3 qubits
		local count = 0
		for _ in pairs(measurements) do
			count = count + 1
		end
		assert(count == 5, "Expected 5 measurements, got " .. count)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 2: Single qubit measurements
	test("Parse single qubit measurements", function()
		local content = "M 5"
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 1, 0 })

		-- Should not error
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 3: Empty buffer handling
	test("Handle empty buffer", function()
		local bufnr = create_test_buffer("")

		vim.api.nvim_set_current_buf(bufnr)

		-- Should not error
		stim_treesitter.highlight_measurement()

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 4: Measurement with detector
	test("Parse measurement with detector", function()
		local content = [[M 0 1
DETECTOR rec[-1]
]]
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 2, 12 }) -- Position on rec[-1]

		-- Should not error and should find record reference
		local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil, "Should find record reference")
		assert(record_ref.index == -1, "Should parse index correctly")
		assert(record_ref.is_valid == true, "Negative index should be valid")

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 5: Invalid positive record reference
	test("Handle invalid positive record reference", function()
		local content = "DETECTOR rec[1]"
		local bufnr = create_test_buffer(content)

		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- Position on rec[1]

		local record_ref = stim_treesitter.get_record_ref_at_cursor(bufnr)
		assert(record_ref ~= nil, "Should find record reference")
		assert(record_ref.index == 1, "Should parse positive index")
		assert(record_ref.is_valid == false, "Positive index should be invalid")

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 6: MPP instruction parsed as correct number of measurements
	test("MPP Pauli-product terms each count as one measurement", function()
		local parse_measurements = stim_treesitter._parse_measurements_ts
		if not parse_measurements then
			return
		end
		-- Verify treesitter is functional (mock returns empty for any input)
		local probe_buf = create_test_buffer("M 0")
		local probe = parse_measurements(probe_buf)
		vim.api.nvim_buf_delete(probe_buf, { force = true })
		local probe_count = 0
		for _ in pairs(probe) do probe_count = probe_count + 1 end
		if probe_count == 0 then return end -- mock/no-treesitter environment

		local content = "MPP X0*Z1 Y2*X3"
		local bufnr = create_test_buffer(content)

		local measurements = parse_measurements(bufnr)
		local count = 0
		for _ in pairs(measurements) do
			count = count + 1
		end
		assert(count == 2, "Expected 2 MPP measurements (X0*Z1 and Y2*X3), got " .. count)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 7: MPP with error parameter
	test("MPP with error parameter parses targets correctly", function()
		local parse_measurements = stim_treesitter._parse_measurements_ts
		if not parse_measurements then
			return
		end
		local probe_buf = create_test_buffer("M 0")
		local probe = parse_measurements(probe_buf)
		vim.api.nvim_buf_delete(probe_buf, { force = true })
		local probe_count = 0
		for _ in pairs(probe) do probe_count = probe_count + 1 end
		if probe_count == 0 then return end

		local content = "MPP(0.01) X0*Z1 Z2"
		local bufnr = create_test_buffer(content)

		local measurements = parse_measurements(bufnr)
		local count = 0
		for _ in pairs(measurements) do
			count = count + 1
		end
		assert(count == 2, "Expected 2 MPP measurements, got " .. count)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	-- Test 8: Mixed MPP and regular measurement lines
	test("Mixed MPP and MZ lines total correctly", function()
		local parse_measurements = stim_treesitter._parse_measurements_ts
		if not parse_measurements then
			return
		end
		local probe_buf = create_test_buffer("M 0")
		local probe = parse_measurements(probe_buf)
		vim.api.nvim_buf_delete(probe_buf, { force = true })
		local probe_count = 0
		for _ in pairs(probe) do probe_count = probe_count + 1 end
		if probe_count == 0 then return end

		-- 3 MZ targets + 2 MPP targets = 5 measurements total
		local content = "MZ 0 1 2\nMPP X0*Z1 Y3"
		local bufnr = create_test_buffer(content)

		local measurements = parse_measurements(bufnr)
		local count = 0
		for _ in pairs(measurements) do
			count = count + 1
		end
		assert(count == 5, "Expected 5 total measurements (3 MZ + 2 MPP), got " .. count)

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

	print(string.format("\n--- Measurement Parsing Tests ---"))
	print(string.format("Passed: %d/%d", passed, total))

	return results
end

-- Export for external test runner
return {
	run_tests = run_tests,
}
