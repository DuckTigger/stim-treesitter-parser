-- Auto-registers the stim parser with nvim-treesitter at plugin load time,
-- independently of setup() being called. This ensures :TSInstall stim works
-- even when the plugin is lazy-loaded or setup() hasn't run yet.
--
-- Neovim sources every file in plugin/ on startup (or when the plugin is
-- loaded by a plugin manager), so this runs before the user's config function.

local STIM_PARSER_ENTRY = {
	install_info = {
		url = "https://github.com/DuckTigger/stim-treesitter-parser",
		files = { "src/parser.c" },
		branch = "main",
		generate_requires_npm = false,
		requires_generate_from_grammar = false,
	},
	filetype = "stim",
}

local function register_parser()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return
	end

	if type(parsers.get_parser_configs) == "function" then
		parsers.get_parser_configs().stim = STIM_PARSER_ENTRY
	elseif parsers.configs ~= nil then
		parsers.configs.stim = STIM_PARSER_ENTRY
	else
		parsers.stim = STIM_PARSER_ENTRY
	end
end

-- Register immediately on load
register_parser()

-- Re-register after every reload_parsers() call (nvim-treesitter wipes the
-- table internally during TSInstall/TSUpdate)
vim.api.nvim_create_autocmd("User", {
	pattern = "TSUpdate",
	callback = register_parser,
})

-- Register the filetype mapping for Neovim's built-in treesitter API
vim.filetype.add({ extension = { stim = "stim" } })
if vim.treesitter and vim.treesitter.language then
	vim.treesitter.language.register("stim", "stim")
end
