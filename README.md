# stim-treesitter

A Neovim plugin providing [Tree-sitter](https://tree-sitter.github.io/) syntax highlighting and circuit-analysis tools for [Stim](https://github.com/quantumlib/Stim) quantum circuit (`.stim`) files.

## Features

- **Syntax highlighting** — full Tree-sitter grammar for `.stim` files (gates, targets, detectors, repeat blocks, comments, etc.)
- **Measurement record resolution** — cursor-aware highlight that traces a `rec[-N]` reference back to the exact measurement qubit it names, with live inline highlighting as you move the cursor
- **Measurement info** — floating popup showing which measurement instruction and line a `rec[-N]` index resolves to; flags invalid positive indices as errors
- **Qubit coordinates lookup** — looks up the `QUBIT_COORDS` definition for any qubit number under the cursor
- **Shift record indices** — bulk-renumber `rec[N]` indices in a visual selection by an interactive offset, with optional threshold filtering
- **Parser health check** — verifies the Stim Tree-sitter parser is compiled and active in the current buffer

---

## Installation

### Option A — Lazy.nvim (recommended)

```lua
{
  "DuckTigger/stim-treesitter-parser",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("stim-treesitter-config").setup({
      -- defaults shown:
      highlight_measurements = true,
      keymaps = { show_info = "<leader>si" },
    })
  end,
}
```

Then compile the parser once:

```vim
:TSInstall stim
```

### Option B — Standalone `stim-vim` app

Installs an isolated Neovim environment (separate config, data, and cache) that never touches your existing setup:

```bash
bash install-stim-vim.sh
```

This bootstraps Lazy.nvim, installs the plugin, compiles the parser, and creates a `stim-vim` wrapper in `~/.local/bin`. Add that directory to `$PATH` if prompted, then open files with:

```bash
stim-vim circuit.stim
```

To remove the standalone app:

```bash
bash install-stim-vim.sh --uninstall
```

---

## Commands

| Command | Description |
|---|---|
| `:StimInfoTS` | Show which measurement a `rec[-N]` under the cursor points to |
| `:StimCheckParser` | Report whether the Stim Tree-sitter parser is active |
| `:StimQubitCoords` | Show `QUBIT_COORDS` for the qubit number under the cursor |
| `:'<,'>StimShiftRecords` | Shift `rec[N]` indices in the visual selection |

---

## Default Keybindings

All keymaps are buffer-local (only active in `.stim` files). The `<leader>si` binding is configurable; the rest are always set.

| Key | Mode | Action |
|---|---|---|
| `<leader>si` | Normal | Show measurement info for `rec[-N]` under cursor (`:StimInfoTS`) |
| `<leader>sq` | Normal | Show qubit coordinates for number under cursor (`:StimQubitCoords`) |
| `<leader>sr` | Visual | Shift `rec[N]` indices in selection (`:'<,'>StimShiftRecords`) |

To change the `<leader>si` binding, pass a different key in `setup()`:

```lua
require("stim-treesitter-config").setup({
  keymaps = { show_info = "<leader>mi" },
})
```

---

## Requirements

- Neovim 0.12+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- A C compiler (`gcc` or `clang`) — used by nvim-treesitter to compile the parser on first install
