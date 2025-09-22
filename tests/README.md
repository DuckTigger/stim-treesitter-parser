# Stim Tree-sitter Plugin Tests

This directory contains unit and integration tests for the stim-treesitter Neovim plugin.

## Test Structure

### Test Files

- **`test_measurement_parsing.lua`** - Tests for basic measurement parsing functionality
- **`test_repeat_blocks.lua`** - Tests for REPEAT block handling and measurement counting
- **`test_record_resolution.lua`** - Tests for record reference resolution (`rec[-n]`)
- **`test_integration.lua`** - Integration tests for the full plugin workflow
- **`run_all_tests.lua`** - Test runner that executes all test suites

### Fixture Files

The `fixtures/` directory contains sample Stim circuit files used in tests:

- **`simple.stim`** - Basic measurements and detectors
- **`repeat.stim`** - REPEAT blocks with various configurations
- **`nested_repeat.stim`** - Nested REPEAT blocks for complex scenarios

## Running Tests

### From Command Line (Standalone)

**CLI Test Runner** - Works without Neovim:
```bash
# Run CLI-compatible tests (recommended for CI)
lua tests/cli_test_runner.lua

# Make executable and run
chmod +x tests/cli_test_runner.lua
./tests/cli_test_runner.lua
```

### From Neovim (Full Tests)

**Neovim Test Runner** - Requires Neovim environment:
```vim
:luafile tests/run_all_tests.lua
```

Or run individual test suites:

```vim
:lua require('tests.test_measurement_parsing').run_tests()
:lua require('tests.test_repeat_blocks').run_tests()
:lua require('tests.test_record_resolution').run_tests()
:lua require('tests.test_integration').run_tests()
```

### CI/CD Integration

The CLI test runner is designed for continuous integration:

```bash
# In GitHub Actions or other CI systems
cd tests
lua cli_test_runner.lua
echo "Exit code: $?"
```

## Test Coverage

### Measurement Parsing Tests
- ✅ Basic measurement parsing (`M 0 1 2`)
- ✅ Single qubit measurements (`M 5`)
- ✅ Empty buffer handling
- ✅ Measurements with detectors
- ✅ Invalid positive record references

### REPEAT Block Tests
- ✅ Simple REPEAT blocks (`REPEAT 3 { M 0 1 }`)
- ✅ Multiple REPEAT blocks in sequence
- ✅ Nested REPEAT blocks
- ✅ Various repeat counts (1, 2, 3, 5)
- ✅ REPEAT blocks with surrounding measurements
- ✅ Empty REPEAT blocks (edge case)

### Record Resolution Tests
- ✅ Basic record reference resolution (`rec[-1]`, `rec[-2]`)
- ✅ Record references across multiple measurements
- ✅ Invalid positive record references (`rec[0]`, `rec[1]`)
- ✅ Out of range record references
- ✅ Record references with REPEAT blocks
- ✅ Complex nested REPEAT scenarios
- ✅ Cursor positioning edge cases
- ✅ Show info functionality

### Integration Tests
- ✅ Full workflow with fixture files
- ✅ Plugin setup and command registration
- ✅ Highlighting persistence across cursor movements
- ✅ Error handling with malformed input
- ✅ Performance with larger circuits (100+ measurements)
- ✅ Multiple buffer handling

## Test Framework

The tests use a simple custom testing framework with two modes:

### CLI Mode (`cli_test_runner.lua`)
- **Mock Vim API**: Complete vim.* function mocking for standalone execution
- **Simplified tests**: Core functionality tests that don't require tree-sitter
- **CI-friendly**: Exit codes, no GUI dependencies
- **Fast execution**: Minimal setup overhead

### Neovim Mode (`run_all_tests.lua`)
- **Full Vim API**: Real Neovim environment with tree-sitter support
- **Complete tests**: All functionality including tree-sitter parsing
- **Interactive**: Runs within Neovim editor

Both frameworks provide:
- `test(name, test_fn)` helper for individual tests
- `assert()` for test assertions
- Temporary buffer creation and cleanup
- Detailed error reporting
- Pass/fail statistics

## Adding New Tests

To add new tests:

1. **Create a new test file** following the naming pattern `test_*.lua`

2. **Follow the test template**:
```lua
local function run_tests()
    local results = {}

    local function test(name, test_fn)
        -- Test execution logic
    end

    test("Your test name", function()
        -- Your test code with assertions
        assert(condition, "error message")
    end)

    return results
end

return { run_tests = run_tests }
```

3. **Add your test suite** to `run_all_tests.lua`:
```lua
local your_tests = require('test_your_module')
all_results.your_module = your_tests.run_tests()
```

4. **Create fixture files** if needed in the `fixtures/` directory

## Notes

### CLI Mode
- **No dependencies**: Works with just Lua 5.4+
- **Mock environment**: Uses `mock_vim.lua` to simulate Neovim API
- **Limited functionality**: Basic parsing and validation tests only
- **CI/CD ready**: Perfect for automated testing pipelines

### Neovim Mode
- **Full functionality**: Requires Neovim with tree-sitter support
- **Real parser**: Uses actual tree-sitter Stim parser if installed
- **Interactive**: Can be run from within Neovim editor
- **Complete coverage**: Tests all plugin features

### General
- Tests clean up temporary buffers automatically
- Performance tests include timing assertions (< 100ms for large circuits)
- Exit codes: 0 for success, 1 for failure (CLI mode)