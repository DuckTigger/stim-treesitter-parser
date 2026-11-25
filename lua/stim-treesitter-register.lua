-- Registers the stim parser with nvim-treesitter so `:TSInstall stim` works.
--
-- Supports both nvim-treesitter branches:
--   * master (frozen, nvim <= 0.11): parser configs live in get_parser_configs().
--   * main (nvim >= 0.12): parsers are plain entries on the nvim-treesitter.parsers
--     table. That module is reloaded (wiping custom entries) before each install,
--     after which a `User TSUpdate` autocmd fires, so registration must happen there.

local M = {}

local URL = "https://github.com/DuckTigger/stim-treesitter-parser"

-- nvim-treesitter master format
local MASTER_ENTRY = {
	install_info = {
		url = URL,
		files = { "src/parser.c" },
		branch = "main",
		generate_requires_npm = false,
		requires_generate_from_grammar = false,
	},
	filetype = "stim",
}

-- nvim-treesitter main format. `queries` copies queries/stim into the
-- install dir (stdpath("data")/site/queries/stim), so highlighting works even
-- before this plugin is loaded onto the runtimepath.
local MAIN_ENTRY = {
	install_info = {
		url = URL,
		branch = "main",
		queries = "queries/stim",
	},
}

local function register()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return false
	end
	if type(parsers.get_parser_configs) == "function" then
		parsers.get_parser_configs().stim = MASTER_ENTRY
	else
		parsers.stim = MAIN_ENTRY
	end
	return true
end

local done = false

--- Register now and (on the main branch) on every future TSUpdate. Idempotent.
function M.setup()
	if done then
		return
	end
	done = true
	vim.api.nvim_create_autocmd("User", {
		pattern = "TSUpdate",
		group = vim.api.nvim_create_augroup("StimTreesitterRegister", { clear = true }),
		-- Must not return true: that would delete the autocmd after the first TSUpdate.
		callback = function()
			register()
		end,
	})
	register()
	-- Retry once all plugins have loaded, in case nvim-treesitter is lazy-loaded
	-- (master only; main does not support lazy-loading).
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			register()
		end,
	})
	vim.treesitter.language.register("stim", "stim")
end

return M
