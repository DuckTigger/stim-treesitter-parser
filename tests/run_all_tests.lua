#!/usr/bin/env lua

-- Test runner for all stim-treesitter tests
-- Usage: lua tests/run_all_tests.lua
-- Or from Neovim: :luafile tests/run_all_tests.lua

local function run_all_tests()
	print("=== Stim Tree-sitter Plugin Test Suite ===\n")

	-- Test results storage
	local all_results = {
		measurement_parsing = {},
		repeat_blocks = {},
		record_resolution = {},
		integration = {},
		shift_records = {},
	}

	-- Add current directory to package path so we can require test modules
	local current_dir = vim.fn.expand("%:p:h")
	package.path = current_dir .. "/?.lua;" .. package.path

	-- Run each test suite
	print("Running measurement parsing tests...")
	local measurement_tests = require("test_measurement_parsing")
	all_results.measurement_parsing = measurement_tests.run_tests()

	print("\nRunning REPEAT block tests...")
	local repeat_tests = require("test_repeat_blocks")
	all_results.repeat_blocks = repeat_tests.run_tests()

	print("\nRunning record resolution tests...")
	local resolution_tests = require("test_record_resolution")
	all_results.record_resolution = resolution_tests.run_tests()

	print("\nRunning integration tests...")
	local integration_tests = require("test_integration")
	all_results.integration = integration_tests.run_tests()

	print("\nRunning shift_records tests...")
	local shift_tests = require("test_shift_records")
	all_results.shift_records = shift_tests.run_tests()

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
					error = result.error,
				})
			end
		end
	end

	-- Print summary
	print("\n" .. string.rep("=", 50))
	print(string.format("TEST SUMMARY: %d/%d tests passed", total_passed, total_tests))

	if #failed_tests > 0 then
		print("\nFAILED TESTS:")
		for _, failure in ipairs(failed_tests) do
			print(string.format("  [%s] %s: %s", failure.suite, failure.name, tostring(failure.error)))
		end
		print(string.rep("=", 50))
		return false
	else
		print("All tests passed! 🎉")
		print(string.rep("=", 50))
		return true
	end
end

-- If this file is being executed directly (not required), run the tests
if arg and arg[0] then
	-- Running as standalone script
	local success = run_all_tests()
	os.exit(success and 0 or 1)
else
	-- Being required from Neovim or another Lua script
	return {
		run_all_tests = run_all_tests,
	}
end
