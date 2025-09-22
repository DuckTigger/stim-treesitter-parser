# Continuous Integration Setup

This document describes the CI/CD pipeline for the stim-treesitter plugin.

## GitHub Actions Workflow

The repository includes a comprehensive GitHub Actions workflow (`.github/workflows/test.yml`) that runs on:

- **Pull requests** to `main` branch
- **Push events** to `main` branch

## Test Jobs

### 1. CLI Tests
- **OS**: Ubuntu Latest
- **Dependencies**: Lua 5.4
- **Description**: Runs standalone CLI tests without Neovim
- **Test file**: `tests/cli_test_runner.lua`
- **Features**:
  - Mock Neovim API
  - Core functionality validation
  - Record reference parsing
  - Basic REPEAT block handling

### 2. Neovim Integration Tests
- **OS**: Ubuntu Latest
- **Dependencies**: Neovim (stable), Lua
- **Description**: Tests plugin integration with real Neovim
- **Features**:
  - Syntax validation of Lua files
  - Module loading verification
  - Setup function testing
  - Basic integration workflow

### 3. Lint and Format
- **OS**: Ubuntu Latest
- **Dependencies**: Lua 5.4, luarocks, luacheck
- **Description**: Code quality and formatting checks
- **Checks**:
  - Lua syntax and style (luacheck)
  - File permissions validation
  - Code formatting consistency

### 4. Documentation
- **OS**: Ubuntu Latest
- **Description**: Documentation validation and link checking
- **Features**:
  - Markdown file validation
  - Link checking (with retries)
  - Documentation completeness

### 5. End-to-End Integration
- **OS**: Ubuntu Latest
- **Dependencies**: Neovim, Lua 5.4
- **Description**: Complete workflow testing
- **Features**:
  - CLI + Neovim combined testing
  - Fixture file validation
  - Test report generation
  - Artifact upload

## Test Coverage

### CLI Tests (Standalone)
```bash
lua tests/cli_test_runner.lua
```

**Covered functionality:**
- ✅ Mock Vim API functionality
- ✅ Basic measurement parsing
- ✅ Record reference validation
- ✅ Invalid reference detection
- ✅ REPEAT block handling
- ✅ Plugin setup verification
- ✅ Info display functionality

### Neovim Tests (Integration)
```bash
nvim --headless -c "luafile tests/..." -c "qa!"
```

**Covered functionality:**
- ✅ Module loading and syntax
- ✅ Setup function execution
- ✅ Command registration
- ✅ Real buffer operations
- ✅ Highlighting functionality

## Configuration Files

### `.github/workflows/test.yml`
Main workflow definition with:
- Job dependencies
- Matrix builds
- Artifact handling
- Conditional steps

### `.github/markdown-link-check-config.json`
Markdown link checker configuration:
- Timeout settings (20s)
- Retry logic for 429 errors
- Pattern ignoring for localhost
- Custom headers for GitHub

## Running CI Locally

### Prerequisites
```bash
# Install Lua
sudo apt-get install lua5.4

# Install Neovim
sudo apt-get install neovim

# Install luarocks and luacheck
sudo apt-get install luarocks
luarocks install luacheck
```

### Run All Tests
```bash
# CLI tests
cd tests && lua cli_test_runner.lua

# Lint check
luacheck *.lua --ignore 113 --ignore 212 --ignore 213

# Neovim integration
nvim --headless -c "luafile stim-treesitter.lua" -c "qa!"
```

## Status Badges

Add these to your README.md:

```markdown
[![Test Status](https://github.com/username/stim-tresitter/actions/workflows/test.yml/badge.svg)](https://github.com/username/stim-tresitter/actions/workflows/test.yml)
```

## Failure Handling

### Test Failures
- **CLI tests fail**: Check `tests/cli_test_runner.lua` output
- **Neovim tests fail**: Verify Lua syntax and module loading
- **Lint failures**: Run `luacheck` locally to see issues

### Common Issues
1. **Path issues**: Ensure relative paths work in CI environment
2. **Permission errors**: Check file permissions (644 for .lua files)
3. **Missing dependencies**: Verify all required packages in workflow
4. **Timeout errors**: Increase timeout values if needed

## Artifacts

The workflow generates:
- **Test reports**: Summary of test results
- **Coverage data**: Test coverage information (when available)
- **Lint reports**: Code quality analysis

Artifacts are retained for 30 days and can be downloaded from the GitHub Actions interface.

## Security Considerations

- **No secrets required**: All tests use public data
- **Read-only operations**: Tests don't modify repository state
- **Sandboxed execution**: Each job runs in isolated containers
- **Dependency pinning**: Specific versions for reproducibility

## Performance

**Typical execution times:**
- CLI tests: ~30 seconds
- Neovim tests: ~45 seconds
- Lint checks: ~20 seconds
- Documentation: ~15 seconds
- Integration: ~60 seconds

**Total pipeline time**: ~3 minutes