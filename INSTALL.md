# Tree-sitter Stim Grammar Installation

This guide will help you install and set up the tree-sitter grammar for Stim quantum circuit files.

## Prerequisites

- **Neovim** (0.8+ with tree-sitter support)
- **Node.js and npm** (for building the grammar)
- **Git**
- **C compiler** (gcc or clang)
- **Tree-sitter CLI tool**

## Step 1: Install Tree-sitter CLI

First, install the tree-sitter CLI globally:

```bash
npm install -g tree-sitter-cli
```

**Alternative installation methods:**
```bash
# Using Homebrew (macOS)
brew install tree-sitter

# Using Cargo (Rust)
cargo install tree-sitter-cli

# Using yarn
yarn global add tree-sitter-cli
```

**Verify installation:**
```bash
tree-sitter --version
```

## Step 2: Set Up the Grammar

Since this repository already contains the grammar files, you can use them directly:

### Option A: Use This Repository (Recommended)

```bash
# Clone or use the current directory
cd /path/to/stim-tresitter

# Generate the parser
tree-sitter generate

# Test the grammar with provided fixtures
tree-sitter test

# Build the shared library
tree-sitter build
```

### Option B: Create From Scratch

```bash
# Create a new grammar directory
mkdir -p ~/.local/share/tree-sitter-stim
cd ~/.local/share/tree-sitter-stim

# Initialize the grammar
tree-sitter init stim

# Copy the grammar files from this repository
cp /path/to/stim-tresitter/grammar.js .
cp /path/to/stim-tresitter/package.json .
cp -r /path/to/stim-tresitter/queries .

# Generate and build
tree-sitter generate
tree-sitter build
```

## Step 3: Install in Neovim

### Method 1: Manual Installation

```bash
# Create parser directory if it doesn't exist
mkdir -p ~/.local/share/nvim/site/pack/packer/start/nvim-treesitter/parser

# Copy the compiled parser
cp stim.so ~/.local/share/nvim/site/pack/packer/start/nvim-treesitter/parser/

# Or if using a different path:
mkdir -p ~/.local/share/nvim/tree-sitter-parsers
cp stim.so ~/.local/share/nvim/tree-sitter-parsers/
```

### Method 2: Using nvim-treesitter

Add to your Neovim configuration:

```lua
-- In your init.lua or equivalent config file
local parser_config = require('nvim-treesitter.parsers').get_parser_configs()

parser_config.stim = {
  install_info = {
    url = "/path/to/stim-tresitter", -- Local path to this repository
    files = {"src/parser.c"},
    branch = "main",
    generate_requires_npm = false,
    requires_generate_from_grammar = true,
  },
  filetype = "stim",
}

require('nvim-treesitter.configs').setup({
  ensure_installed = {
    -- your other parsers...
  },

  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})
```

### Method 3: Local Development Setup

For development, create a symlink:

```bash
# Link to your development directory
ln -sf /path/to/stim-tresitter ~/.local/share/nvim/site/pack/dev/start/tree-sitter-stim
```

## Step 4: Configure File Type Detection

Add to your Neovim configuration:

```lua
-- Detect .stim files
vim.filetype.add({
  extension = {
    stim = 'stim',
  },
  filename = {
    ['*.stim'] = 'stim',
  },
})
```

## Step 5: Set Up the Stim Tree-sitter Plugin

Copy the Lua plugin files and configure:

```lua
-- In your init.lua
-- Add to your package path if needed
package.path = package.path .. ';/path/to/stim-tresitter/?.lua'

-- Load and setup the plugin
require('stim-treesitter').setup()

-- Optional: Set up keybindings
vim.keymap.set('n', '<leader>si', ':StimInfoTS<CR>', { desc = 'Stim: Show measurement info' })
```

## Step 6: Verify Installation

1. **Check parser installation:**
   ```vim
   :TSInstallInfo stim
   ```

2. **Test with a .stim file:**
   ```vim
   :edit test.stim
   ```

3. **Verify highlighting:**
   - Open a .stim file
   - Check that syntax highlighting is applied
   - Run `:TSHighlightCapturesUnderCursor` to see highlighting groups

4. **Test the plugin:**
   ```vim
   :StimCheckParser
   :StimInfoTS
   ```

## Example .stim File for Testing

Create a test file to verify everything works:

```stim
# Test file: test.stim
M 0 1
DETECTOR rec[-1]
REPEAT 3 {
   M 2 3
}
DETECTOR rec[-2]
TICK
X 0
CNOT 0 1
```

## Troubleshooting

### Tree-sitter CLI Issues
- **`npm error could not determine executable to run`**: Install tree-sitter CLI globally first
- **Command not found**: Ensure your npm global bin directory is in PATH
- **Permission errors**: Use `sudo` for global npm installs if needed

### Grammar Build Issues
- **Build fails**: Ensure you have a C compiler installed
- **Missing src/parser.c**: Run `tree-sitter generate` first
- **Grammar errors**: Check `grammar.js` syntax with `tree-sitter generate`

### Neovim Integration Issues
- **Parser not found**: Check the parser file location and permissions
- **Highlighting not working**: Verify `highlights.scm` is in `queries/` directory
- **Plugin not loading**: Check Lua syntax and require paths

### Testing the Grammar
```bash
# Test grammar generation
tree-sitter generate

# Test with example files
tree-sitter parse test.stim

# Run test suite (if available)
tree-sitter test

# Debug parsing
tree-sitter parse --debug test.stim
```

### File Structure Check
Your directory should look like:
```
stim-tresitter/
├── grammar.js          # Grammar definition
├── package.json        # Package configuration
├── src/
│   └── parser.c        # Generated parser (after tree-sitter generate)
├── queries/
│   └── highlights.scm  # Syntax highlighting rules
├── stim-treesitter.lua # Neovim plugin
└── stim.so            # Compiled parser (after tree-sitter build)
```

## Alternative Installation Paths

If the standard installation doesn't work, try these paths:

### For nvim-treesitter users:
```bash
# Find your nvim-treesitter installation
find ~/.local/share/nvim -name "nvim-treesitter" -type d

# Copy parser to the found directory
cp stim.so ~/.local/share/nvim/site/pack/packer/start/nvim-treesitter/parser/
```

### For manual installations:
```bash
# Common Neovim data directories
~/.local/share/nvim/tree-sitter-parsers/
~/.config/nvim/parser/
~/.local/share/nvim/site/parser/
```

## Next Steps

Once installed, you'll have:

- ✅ **Syntax highlighting** for .stim files
- ✅ **Tree-sitter parsing** for code structure
- ✅ **Record reference highlighting** (via stim-treesitter.lua)
- ✅ **Measurement tracking** with REPEAT block support
- ✅ **Info commands** for debugging circuits

The installation provides the foundation for working with Stim quantum circuit files in Neovim with full IDE-like features.
