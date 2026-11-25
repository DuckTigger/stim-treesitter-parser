-- Auto-registers the stim parser with nvim-treesitter at plugin load time,
-- independently of setup() being called. This ensures :TSInstall stim works
-- even when setup() hasn't run yet.
--
-- Neovim sources every file in plugin/ on startup (or when the plugin is
-- loaded by a plugin manager), so this runs before the user's config function.
require("stim-treesitter-register").setup()
