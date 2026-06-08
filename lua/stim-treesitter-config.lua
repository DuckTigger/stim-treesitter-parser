-- Stim Tree-sitter configuration
local M = {}

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

-- Register stim with nvim-treesitter, handling three API generations:
--   Gen 1 (old "master"):  parsers.get_parser_configs() exists
--   Gen 2 (mid "main"):    parsers.configs table exists directly
--   Gen 3 (current "main"): direct table assignment; reload_parsers() wipes and
--                           re-fires User/TSUpdate, so we hook that autocmd
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

function M.setup(opts)
	opts = opts or {}
	local defaults = {
		highlight_measurements = true,
		keymaps = { show_info = "<leader>si" },
	}
	opts = vim.tbl_deep_extend("force", defaults, opts)

	if not pcall(require, "nvim-treesitter.parsers") then
		vim.notify("stim-treesitter: nvim-treesitter not found", vim.log.levels.ERROR)
		return
	end

	-- Register immediately (for initial load) and after every reload_parsers() call.
	register_parser()
	vim.api.nvim_create_autocmd("User", {
		pattern = "TSUpdate",
		callback = register_parser,
	})

	-- Map the filetype to the parser name for Neovim's built-in treesitter API.
	vim.treesitter.language.register("stim", "stim")
	vim.filetype.add({ extension = { stim = "stim" } })

	if opts.highlight_measurements then
		require("stim-treesitter").setup()
		if opts.keymaps.show_info then
			vim.keymap.set("n", opts.keymaps.show_info, ":StimInfoTS<CR>", { desc = "Show Stim measurement info" })
		end
	end
end

return M
