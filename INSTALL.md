# Tree-sitter Stim Grammar Installation

This guide will help you install and set up the tree-sitter grammar for Stim quantum circuit files.

## Requirements

- **Neovim** 0.12+
- **[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)** — required; handles parser compilation and highlighting
- **A C compiler** (`gcc` or `clang`) — needed by nvim-treesitter to compile the Stim parser on first install

## Quick Install with Lazy.nvim (Recommended)

This plugin depends on `nvim-treesitter`. If you don't already have it, Lazy will install it automatically via the `dependencies` field below.

```lua
{
  "DuckTigger/stim-treesitter-parser",
  event = "VeryLazy",  -- required if your setup lazy-loads by default (e.g. NvChad)
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require('stim-treesitter-config').setup({
      -- All options are optional; these are the defaults:
      highlight_measurements = true,
      keymaps = { show_info = "<leader>si" },
    })
  end,
}
```

> **NvChad users**: two extra steps are needed:
>
> 1. `event = "VeryLazy"` on the plugin spec (already shown above) so `:TSInstall stim` works.
>
> 2. Enable the treesitter highlight module in your treesitter overrides
>    (`lua/configs/overrides.lua` or equivalent):
>    ```lua
>    M.treesitter = {
>      -- ... your existing config ...
>      highlight = { enable = true },
>    }
>    ```
>    NvChad ships with the highlight module **disabled** by default. Without this,
>    no treesitter syntax colours appear for any language, including stim.
>
> 3. If highlighting still doesn't appear after `:TSInstall stim`, add these lines
>    to your `init.lua` (after `require("lazy").setup(...)`):
>    ```lua
>    vim.treesitter.language.register("stim", "stim")
>    vim.filetype.add({ extension = { stim = "stim" } })
>    ```

After installing, compile the parser:
```vim
:TSInstall stim
```

### Available commands

| Command | Description |
|---|---|
| `:StimInfoTS` | Show measurement info under cursor |
| `:StimCheckParser` | Check tree-sitter parser status |
| `:'<,'>StimShiftRecords` | Shift `rec[N]` indices in visual selection |

Default keymaps (set in `setup()`):

| Key | Mode | Action |
|---|---|---|
| `<leader>si` | Normal | Show measurement info |
| `<leader>sr` | Visual | Shift records |

## Testing the install in an isolated environment

You can test this plugin without touching your real Neovim config using `NVIM_APPNAME` (Neovim 0.9+), which redirects all config and data paths to a separate directory.

### 1. Create a minimal config

```bash
mkdir -p ~/.config/nvim-stim-test/lua
```

Create `~/.config/nvim-stim-test/init.lua`:

```lua
-- Bootstrap Lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- For Neovim 0.12+:
require("lazy").setup({
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  {
    "DuckTigger/stim-treesitter-parser",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require('stim-treesitter-config').setup()
    end,
  },
})
```

### 2. Launch the isolated instance

```bash
NVIM_APPNAME=nvim-stim-test nvim
```

This uses `~/.config/nvim-stim-test/` and `~/.local/share/nvim-stim-test/` — completely separate from your real config. Your existing setup is untouched.

### 3. Install everything

Inside that Neovim instance:
```vim
:Lazy sync
:TSInstall stim
```

### 4. Test it

```bash
NVIM_APPNAME=nvim-stim-test nvim test.stim
```

Try `:StimCheckParser`, `:StimInfoTS`, and `<leader>sr` in visual mode.

### 5. Clean up when done

```bash
rm -rf ~/.config/nvim-stim-test ~/.local/share/nvim-stim-test ~/.cache/nvim-stim-test
```

---

## Prerequisites (manual installation)

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
