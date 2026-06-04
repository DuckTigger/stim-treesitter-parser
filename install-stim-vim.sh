#!/usr/bin/env bash
# install-stim-vim.sh
#
# Creates a standalone "stim-vim" Neovim app for viewing/editing Stim
# quantum circuit files. Uses NVIM_APPNAME isolation — your existing Neovim
# config is never touched.
#
# Requirements: nvim (0.12+), git, a C compiler (gcc or clang)
#
# Usage:
#   bash install-stim-vim.sh            # install
#   bash install-stim-vim.sh --uninstall

set -euo pipefail

APP_NAME="stim-vim"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP_NAME"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APP_NAME"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$APP_NAME"
BIN_DIR="${HOME}/.local/bin"
WRAPPER="$BIN_DIR/$APP_NAME"

# ── colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[stim-vim]${RESET} $*"; }
success() { echo -e "${GREEN}[stim-vim]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[stim-vim]${RESET} $*"; }
die()     { echo -e "${RED}[stim-vim]${RESET} $*" >&2; exit 1; }

# ── uninstall ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
    info "Removing stim-vim..."
    rm -rf "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"
    rm -f "$WRAPPER"
    success "stim-vim removed."
    exit 0
fi

# ── dependency checks ──────────────────────────────────────────────────────
info "Checking dependencies..."

if ! command -v nvim &>/dev/null; then
    die "nvim not found. Install Neovim 0.12+ from https://neovim.io"
fi
NVIM_VERSION=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
NVIM_MAJOR=$(echo "$NVIM_VERSION" | cut -d. -f1)
NVIM_MINOR=$(echo "$NVIM_VERSION" | cut -d. -f2)
if [[ "$NVIM_MAJOR" -lt 1 && "$NVIM_MINOR" -lt 12 ]]; then
    die "Neovim 0.12+ required (found $NVIM_VERSION). Upgrade at https://neovim.io"
fi
info "  nvim $NVIM_VERSION ✓"

command -v git &>/dev/null || die "git not found. Please install git."
info "  git ✓"

CC_FOUND=""
for cc in cc gcc clang; do
    command -v "$cc" &>/dev/null && CC_FOUND="$cc" && break
done
[[ -n "$CC_FOUND" ]] || die "No C compiler found (gcc/clang). Required for compiling the tree-sitter parser."
info "  C compiler ($CC_FOUND) ✓"

# ── write init.lua ─────────────────────────────────────────────────────────
info "Creating config in $CONFIG_DIR ..."
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/init.lua" << 'EOF'
-- stim-vim: standalone Neovim app for Stim quantum circuit files
-- Managed by install-stim-vim.sh

-- ── leader (must be set before lazy / any plugin) ─────────────────────────
vim.g.mapleader      = " "
vim.g.maplocalleader = " "

-- ── editor settings ────────────────────────────────────────────────────────
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.termguicolors  = true
vim.opt.wrap           = false
vim.opt.scrolloff      = 8
vim.opt.sidescrolloff  = 8
vim.opt.signcolumn     = "yes"
vim.opt.cursorline     = true
vim.opt.mouse          = "a"
vim.opt.clipboard      = "unnamedplus"
vim.opt.splitbelow     = true
vim.opt.splitright     = true

-- ── bootstrap lazy.nvim ───────────────────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ── plugins ───────────────────────────────────────────────────────────────
require("lazy").setup({

  -- Catppuccin colorscheme (loaded first, before everything else)
  {
    "catppuccin/nvim",
    name     = "catppuccin",
    priority = 1000,
    opts = {
      flavour                = "mocha",  -- latte | frappe | macchiato | mocha
      transparent_background = false,
      integrations           = { treesitter = true },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- nvim-treesitter: parser management
  -- In v1.0+ there is no configs.setup(); treesitter highlighting is enabled
  -- per-buffer below via a FileType autocmd.
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },

  -- Stim language plugin (parser registration + measurement analysis commands)
  {
    "DuckTigger/stim-treesitter-parser",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("stim-treesitter-config").setup({
        highlight_measurements = true,
        keymaps = { show_info = "<leader>si" },
      })
    end,
  },

}, { ui = { backdrop = 100 } })

-- ── enable treesitter highlighting for stim files ─────────────────────────
-- nvim-treesitter v1.0 removed the global configs.setup(); highlighting is
-- now started per-buffer with vim.treesitter.start().
vim.api.nvim_create_autocmd("FileType", {
  pattern  = "stim",
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})
EOF

success "init.lua written."

# ── headless bootstrap: install plugins ───────────────────────────────────
info "Installing plugins (this may take a minute)..."
NVIM_APPNAME=$APP_NAME nvim --headless -c "Lazy! sync" -c "q" 2>&1 \
  | grep -v "^$" || true
success "Plugins installed."

# ── headless bootstrap: compile stim parser ───────────────────────────────
info "Compiling Stim tree-sitter parser..."
NVIM_APPNAME=$APP_NAME nvim --headless -c "lua
  require('stim-treesitter-config').setup()
  local install = require('nvim-treesitter.install')
  local task = install.install({'stim'}, { force = false })
  task:await(function(err)
    if err then
      io.stderr:write('[stim-vim] parser error: ' .. tostring(err) .. '\n')
    end
    vim.cmd('q')
  end)
" 2>&1 | grep -v "^$" || true

# ── verify parser was compiled ────────────────────────────────────────────
PARSER_SO=$(find "${XDG_DATA_HOME:-$HOME/.local/share}/$APP_NAME" -name "stim.so" 2>/dev/null | head -1)
if [[ -n "$PARSER_SO" ]]; then
    success "Parser compiled: $PARSER_SO"
else
    warn "Parser .so not found — run ':TSInstall stim' on first launch."
fi

# ── create wrapper script ─────────────────────────────────────────────────
info "Creating wrapper script at $WRAPPER ..."
mkdir -p "$BIN_DIR"
cat > "$WRAPPER" << WRAPPER_EOF
#!/usr/bin/env bash
# stim-vim: standalone Neovim app for Stim quantum circuit files
exec env NVIM_APPNAME=$APP_NAME nvim "\$@"
WRAPPER_EOF
chmod +x "$WRAPPER"
success "Wrapper created."

# ── done ──────────────────────────────────────────────────────────────────
echo
if echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
    success "${BOLD}Installation complete!${RESET}"
    echo
    echo -e "  Usage:  ${BOLD}stim-vim circuit.stim${RESET}"
else
    success "${BOLD}Installation complete!${RESET}"
    echo
    warn "$BIN_DIR is not in your PATH."
    echo "  Add to your shell profile (~/.zshrc, ~/.bashrc, etc.):"
    echo -e "    ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
    echo
    echo "  Or run directly:"
    echo -e "    ${BOLD}$WRAPPER circuit.stim${RESET}"
fi
echo
echo "  Commands inside stim-vim (leader key = Space):"
echo "    :TSInstall stim      re-compile parser"
echo "    :StimInfoTS          measurement info under cursor"
echo "    :StimCheckParser     parser status"
echo "    <Space>si            show measurement info"
echo "    <Space>sq            show qubit coordinates"
echo "    <Space>sr            shift rec[] indices (visual mode)"
echo
echo "  To uninstall:"
echo -e "    ${BOLD}bash install-stim-vim.sh --uninstall${RESET}"
