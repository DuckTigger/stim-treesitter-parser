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

local function try_register()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return false
	end

	if type(parsers.get_parser_configs) == "function" then
		parsers.get_parser_configs().stim = STIM_PARSER_ENTRY
	elseif parsers.configs ~= nil then
		parsers.configs.stim = STIM_PARSER_ENTRY
	else
		parsers.stim = STIM_PARSER_ENTRY
	end
	return true
end

-- Try immediately (works if nvim-treesitter is already on rtp)
try_register()

-- Retry after all plugins have loaded (catches lazy-loaded nvim-treesitter)
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = try_register,
})

-- Register stim as a treesitter language alias for the stim filetype.
-- ftdetect/stim.lua handles vim.filetype.add at startup.
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		if vim.treesitter and vim.treesitter.language then
			vim.treesitter.language.register("stim", "stim")
		end
	end,
})
