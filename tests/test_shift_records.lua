-- Tests for StimShiftRecords functionality.
-- These tests cover the three core layers:
--   1. count_measurement_targets   (pure string logic)
--   2. calculate_threshold_default (buffer scan logic)
--   3. _apply_shift / full shift_records (buffer mutation + interactive prompts)
--
-- This file is designed to run in CLI mode (no Neovim / tree-sitter required).
-- It loads the real stim-treesitter.lua via dofile so that the exposed internal
-- helpers (_count_measurement_targets, _calculate_threshold_default, _apply_shift)
-- are available under the returned module table.

local function run_tests()
    -- -----------------------------------------------------------------------
    -- Locate the real module relative to this test file
    -- -----------------------------------------------------------------------
    local script_path = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
    -- Load the real module via dofile so it uses the mock vim already in _G.vim.
    -- We preserve (and restore) any existing package.loaded entry so that
    -- other tests that call require('stim-treesitter') still get the mock.
    local saved_module = package.loaded['stim-treesitter']
    package.loaded['stim-treesitter'] = nil
    local M = dofile(script_path .. '../lua/stim-treesitter.lua')
    package.loaded['stim-treesitter'] = saved_module  -- restore mock for other tests

    local count_targets   = M._count_measurement_targets
    local calc_default    = M._calculate_threshold_default
    local apply_shift     = M._apply_shift

    -- -----------------------------------------------------------------------
    -- Tiny test harness
    -- -----------------------------------------------------------------------
    local results = {}
    local function test(name, fn)
        local ok, err = pcall(fn)
        table.insert(results, { name = name, passed = ok, error = err })
        if ok then
            print("  ✓ " .. name)
        else
            print("  ✗ " .. name .. ": " .. tostring(err))
        end
    end

    -- -----------------------------------------------------------------------
    -- Helpers
    -- -----------------------------------------------------------------------
    local function make_buf(lines)
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        return bufnr
    end

    local function get_lines(bufnr)
        return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    end

    -- -----------------------------------------------------------------------
    -- Section 1: count_measurement_targets
    -- -----------------------------------------------------------------------
    print("\n  -- count_measurement_targets --")

    test("empty line returns 0", function()
        assert(count_targets("") == 0)
    end)

    test("non-measurement gate returns 0", function()
        assert(count_targets("H 0 1") == 0)
        assert(count_targets("CNOT 0 1") == 0)
        assert(count_targets("DETECTOR rec[-1]") == 0)
    end)

    test("M counts space-separated targets", function()
        assert(count_targets("M 0 1 2") == 3, "M 0 1 2 should be 3")
        assert(count_targets("M 5")     == 1, "M 5 should be 1")
    end)

    test("MX, MY, MZ count targets", function()
        assert(count_targets("MX 0 1")    == 2)
        assert(count_targets("MY 5")      == 1)
        assert(count_targets("MZ 0 1 2 3") == 4)
    end)

    test("MPP counts Pauli-product terms", function()
        assert(count_targets("MPP X0*Z1 Y2*X3") == 2)
        assert(count_targets("MPP X0*Z1")        == 1)
        assert(count_targets("MPP X0*Z1 X2*Z3 Y4") == 3)
    end)

    test("gate with error-rate parameter still counts targets", function()
        assert(count_targets("M(0.001) 0 1 2") == 3)
        assert(count_targets("MZ(0.1) 0")      == 1)
    end)

    test("leading whitespace is ignored", function()
        assert(count_targets("   M 0 1 2") == 3)
        assert(count_targets("\tMX 0 1")   == 2)
    end)

    test("gate with no targets returns 0", function()
        assert(count_targets("M") == 0)
    end)

    -- -----------------------------------------------------------------------
    -- Section 2: calculate_threshold_default
    -- -----------------------------------------------------------------------
    print("\n  -- calculate_threshold_default --")

    test("no DETECTOR in selection returns nil, nil", function()
        local bufnr = make_buf({
            "MZ 0 1 2",
            "H 0",
        })
        local n_meas, n_det = calc_default(bufnr, 1, 2)
        assert(n_meas == nil and n_det == nil,
            "expected nil,nil got " .. tostring(n_meas) .. "," .. tostring(n_det))
    end)

    test("matching counts: 3 measurements, 3 detectors", function()
        local bufnr = make_buf({
            "DETECTOR rec[-1]",       -- previous group (line 1)
            "MZ 0 1 2",               -- 3 measurements between groups
            "DETECTOR rec[-3]",       -- selection start (line 3)
            "DETECTOR rec[-2]",
            "DETECTOR rec[-1]",       -- selection end (line 5)
        })
        local n_meas, n_det = calc_default(bufnr, 3, 5)
        assert(n_meas == 3, "expected 3 measurements, got " .. tostring(n_meas))
        assert(n_det  == 3, "expected 3 detectors,   got " .. tostring(n_det))
    end)

    test("mismatch: measurements ≠ detectors", function()
        local bufnr = make_buf({
            "DETECTOR rec[-1]",   -- previous group
            "MZ 0 1 2 3",         -- 4 measurements
            "DETECTOR rec[-4]",   -- selection: only 3 detectors
            "DETECTOR rec[-3]",
            "DETECTOR rec[-2]",
        })
        local n_meas, n_det = calc_default(bufnr, 3, 5)
        assert(n_meas == 4, "expected 4 measurements, got " .. tostring(n_meas))
        assert(n_det  == 3, "expected 3 detectors,   got " .. tostring(n_det))
    end)

    test("no previous DETECTOR: scans from start of file", function()
        local bufnr = make_buf({
            "MZ 0 1",             -- 2 measurements before any DETECTOR
            "DETECTOR rec[-2]",   -- selection start
            "DETECTOR rec[-1]",
        })
        local n_meas, n_det = calc_default(bufnr, 2, 3)
        assert(n_meas == 2, "expected 2 measurements, got " .. tostring(n_meas))
        assert(n_det  == 2, "expected 2 detectors,   got " .. tostring(n_det))
    end)

    test("multiple gate types are all counted", function()
        local bufnr = make_buf({
            "DETECTOR rec[-1]",           -- previous group
            "MX 0 1",                     -- 2
            "MY 2",                       -- 1
            "MZ 3 4 5",                   -- 3  → total 6
            "DETECTOR rec[-6]",           -- selection (1 detector)
        })
        local n_meas, n_det = calc_default(bufnr, 5, 5)
        assert(n_meas == 6, "expected 6, got " .. tostring(n_meas))
        assert(n_det  == 1, "expected 1, got " .. tostring(n_det))
    end)

    test("MPP targets counted correctly in threshold calc", function()
        local bufnr = make_buf({
            "DETECTOR rec[-1]",
            "MPP X0*Z1 Y2*X3",   -- 2 measurements
            "DETECTOR rec[-2]",
            "DETECTOR rec[-1]",
        })
        local n_meas, n_det = calc_default(bufnr, 3, 4)
        assert(n_meas == 2, "expected 2 measurements, got " .. tostring(n_meas))
        assert(n_det  == 2, "expected 2 detectors,   got " .. tostring(n_det))
    end)

    test("non-measurement lines between groups are ignored", function()
        local bufnr = make_buf({
            "DETECTOR rec[-1]",
            "TICK",
            "H 0 1 2",
            "CNOT 0 1",
            "MZ 0 1 2",   -- 3 measurements
            "DETECTOR rec[-3]",
            "DETECTOR rec[-2]",
            "DETECTOR rec[-1]",
        })
        local n_meas, n_det = calc_default(bufnr, 6, 8)
        assert(n_meas == 3, "expected 3, got " .. tostring(n_meas))
        assert(n_det  == 3, "expected 3, got " .. tostring(n_det))
    end)

    -- -----------------------------------------------------------------------
    -- Section 3: _apply_shift (non-interactive buffer mutation)
    -- -----------------------------------------------------------------------
    print("\n  -- _apply_shift --")

    test("records below threshold are shifted", function()
        local bufnr = make_buf({ "DETECTOR rec[-5] rec[-3]" })
        local changed = apply_shift(bufnr, 1, 1, -3, 2)
        local lines = get_lines(bufnr)
        assert(changed == 1, "expected 1 change, got " .. changed)
        assert(lines[1] == "DETECTOR rec[-7] rec[-3]",
            "got: " .. lines[1])
    end)

    test("records at or above threshold are not shifted", function()
        local bufnr = make_buf({ "DETECTOR rec[-3] rec[-2] rec[-1]" })
        local changed = apply_shift(bufnr, 1, 1, -3, 2)
        local lines = get_lines(bufnr)
        assert(changed == 0, "expected 0 changes")
        assert(lines[1] == "DETECTOR rec[-3] rec[-2] rec[-1]", "line should be unchanged")
    end)

    test("boundary value: index == threshold is NOT shifted", function()
        local bufnr = make_buf({ "DETECTOR rec[-5]" })
        local changed = apply_shift(bufnr, 1, 1, -5, 1)
        assert(changed == 0, "rec[-5] < -5 is false, should not shift")
    end)

    test("multiple lines: only selected range is mutated", function()
        local bufnr = make_buf({
            "DETECTOR rec[-10]",   -- line 1 (outside selection)
            "DETECTOR rec[-10]",   -- line 2 (inside)
            "DETECTOR rec[-10]",   -- line 3 (inside)
            "DETECTOR rec[-10]",   -- line 4 (outside)
        })
        apply_shift(bufnr, 2, 3, -5, 2)
        local lines = get_lines(bufnr)
        assert(lines[1] == "DETECTOR rec[-10]", "line 1 should be unchanged")
        assert(lines[2] == "DETECTOR rec[-12]", "line 2 should be shifted")
        assert(lines[3] == "DETECTOR rec[-12]", "line 3 should be shifted")
        assert(lines[4] == "DETECTOR rec[-10]", "line 4 should be unchanged")
    end)

    test("no rec[] references: returns 0 and buffer unchanged", function()
        local bufnr = make_buf({ "H 0 1", "CNOT 0 1" })
        local changed = apply_shift(bufnr, 1, 2, -3, 2)
        assert(changed == 0)
        local lines = get_lines(bufnr)
        assert(lines[1] == "H 0 1")
        assert(lines[2] == "CNOT 0 1")
    end)

    test("multiple records on one line all processed", function()
        local bufnr = make_buf({ "DETECTOR rec[-8] rec[-7] rec[-6] rec[-2] rec[-1]" })
        local changed = apply_shift(bufnr, 1, 1, -5, 3)
        local lines = get_lines(bufnr)
        assert(changed == 3, "expected 3 changes, got " .. changed)
        assert(lines[1] == "DETECTOR rec[-11] rec[-10] rec[-9] rec[-2] rec[-1]",
            "got: " .. lines[1])
    end)

    test("positive shift amount subtracts (makes index more negative)", function()
        local bufnr = make_buf({ "DETECTOR rec[-10]" })
        apply_shift(bufnr, 1, 1, -5, 4)
        local lines = get_lines(bufnr)
        assert(lines[1] == "DETECTOR rec[-14]", "got: " .. lines[1])
    end)

    test("comment lines are not modified", function()
        local bufnr = make_buf({
            "# old: rec[-10]",     -- comment: must not be touched
            "DETECTOR rec[-10]",   -- real line: must be shifted
        })
        local changed = apply_shift(bufnr, 1, 2, -5, 3)
        local lines = get_lines(bufnr)
        assert(lines[1] == "# old: rec[-10]",  "comment should be unchanged, got: " .. lines[1])
        assert(lines[2] == "DETECTOR rec[-13]", "detector should be shifted, got: " .. lines[2])
        assert(changed == 1, "only 1 change expected, got " .. changed)
    end)

    test("zero measurements between groups: threshold defaults to -(detector count)", function()
        -- Two DETECTOR groups back-to-back with no measurements in between.
        -- n_meas = 0, n_det = 2; they disagree → use n_det (2).
        local bufnr = make_buf({
            "DETECTOR rec[-1]",   -- previous group
            "DETECTOR rec[-2]",   -- selection: 2 detectors, 0 measurements
            "DETECTOR rec[-1]",
        })
        local n_meas, n_det = calc_default(bufnr, 2, 3)
        assert(n_meas == 0, "expected 0 measurements, got " .. tostring(n_meas))
        assert(n_det  == 2, "expected 2 detectors,   got " .. tostring(n_det))
    end)

    -- -----------------------------------------------------------------------
    -- Section 4: full shift_records with mocked vim.ui.input
    -- -----------------------------------------------------------------------
    print("\n  -- shift_records (interactive, mocked prompts) --")

    test("cancelling threshold prompt leaves buffer unchanged", function()
        local bufnr = make_buf({ "DETECTOR rec[-10]" })
        vim.api.nvim_set_current_buf(bufnr)
        vim.set_ui_inputs({ nil })  -- <Esc> on threshold prompt
        M.shift_records(1, 1)
        local lines = get_lines(bufnr)
        assert(lines[1] == "DETECTOR rec[-10]", "buffer should be unchanged")
    end)

    test("cancelling shift prompt leaves buffer unchanged", function()
        local bufnr = make_buf({ "DETECTOR rec[-10]" })
        vim.api.nvim_set_current_buf(bufnr)
        vim.set_ui_inputs({ "-5", nil })  -- enter threshold, <Esc> shift
        M.shift_records(1, 1)
        local lines = get_lines(bufnr)
        assert(lines[1] == "DETECTOR rec[-10]", "buffer should be unchanged")
    end)

    test("explicit threshold and shift applied correctly", function()
        local bufnr = make_buf({ "DETECTOR rec[-10] rec[-2]" })
        vim.api.nvim_set_current_buf(bufnr)
        vim.set_ui_inputs({ "-5", "3" })
        M.shift_records(1, 1)
        local lines = get_lines(bufnr)
        assert(lines[1] == "DETECTOR rec[-13] rec[-2]", "got: " .. lines[1])
    end)

    test("empty threshold input uses auto-computed default", function()
        -- Buffer: 2 measurements then 2 DETECTORs → default threshold = -2
        local bufnr = make_buf({
            "DETECTOR rec[-1]",   -- previous group
            "MZ 0 1",             -- 2 measurements
            "DETECTOR rec[-10]",  -- selection: 2 detectors
            "DETECTOR rec[-8]",
        })
        vim.api.nvim_set_current_buf(bufnr)
        -- Empty string → use default (-2); shift = 2
        vim.set_ui_inputs({ "", "2" })
        M.shift_records(3, 4)
        local lines = get_lines(bufnr)
        -- rec[-10] < -2 → shifts to rec[-12]; rec[-8] < -2 → rec[-10]
        assert(lines[3] == "DETECTOR rec[-12]", "got: " .. lines[3])
        assert(lines[4] == "DETECTOR rec[-10]", "got: " .. lines[4])
    end)

    test("invalid threshold value notifies error", function()
        local bufnr = make_buf({ "DETECTOR rec[-10]" })
        vim.api.nvim_set_current_buf(bufnr)
        vim.set_ui_inputs({ "notanumber", "2" })
        -- Should not crash; buffer should be unchanged
        M.shift_records(1, 1)
        local lines = get_lines(bufnr)
        assert(lines[1] == "DETECTOR rec[-10]")
    end)

    test("invalid shift amount notifies error and leaves buffer unchanged", function()
        local bufnr = make_buf({ "DETECTOR rec[-10]" })
        vim.api.nvim_set_current_buf(bufnr)
        vim.set_ui_inputs({ "-5", "notanumber" })
        M.shift_records(1, 1)
        local lines = get_lines(bufnr)
        assert(lines[1] == "DETECTOR rec[-10]", "buffer should be unchanged, got: " .. lines[1])
    end)

    test("mismatch: auto-default uses detector count, not measurement count", function()
        -- 4 measurements between groups but only 3 DETECTORs in selection.
        -- The mismatch warning fires; threshold is clamped to -3 (detector count).
        local bufnr = make_buf({
            "DETECTOR rec[-1]",   -- previous group
            "MZ 0 1 2 3",         -- 4 measurements
            "DETECTOR rec[-10]",  -- selection: 3 detectors → threshold = -3
            "DETECTOR rec[-8]",
            "DETECTOR rec[-6]",
        })
        vim.api.nvim_set_current_buf(bufnr)
        -- Empty threshold → use auto-default (-3 from detector count); shift = 1
        vim.set_ui_inputs({ "", "1" })
        M.shift_records(3, 5)
        local lines = get_lines(bufnr)
        -- All three have index < -3, so all shift by 1
        assert(lines[3] == "DETECTOR rec[-11]", "got: " .. lines[3])
        assert(lines[4] == "DETECTOR rec[-9]",  "got: " .. lines[4])
        assert(lines[5] == "DETECTOR rec[-7]",  "got: " .. lines[5])
    end)

    -- -----------------------------------------------------------------------
    -- Summary
    -- -----------------------------------------------------------------------
    local passed, total = 0, #results
    for _, r in ipairs(results) do
        if r.passed then passed = passed + 1 end
    end
    print(string.format("\n  --- Shift Records Tests: %d/%d passed ---", passed, total))
    return results
end

return { run_tests = run_tests }
