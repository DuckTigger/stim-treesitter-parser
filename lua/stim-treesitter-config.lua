-- Stim Tree-sitter configuration
-- Parser registration is also handled by plugin/stim-treesitter.lua at load time,
-- but we register here too as a fallback for unusual loading orders.
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

	-- Ensure parser is registered (plugin/ handles this at load time, but
	-- register here too in case of unusual lazy-loading order).
	register_parser()
	vim.treesitter.language.register("stim", "stim")
	vim.filetype.add({ extension = { stim = "stim" } })

	-- Enable treesitter highlighting for stim buffers.
	-- nvim-treesitter's highlight module only activates for filetypes it knew
	-- about at initialisation time. Since stim is a custom parser, we start it
	-- explicitly per-buffer. This works with both old (configs.setup) and new
	-- (v1.0+) nvim-treesitter APIs, and plays nicely with NvChad.
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "stim",
		callback = function(args)
			pcall(vim.treesitter.start, args.buf)
		end,
	})

	-- Also start highlighting in any stim buffers already open (e.g. if setup()
	-- is called after the file was loaded).
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf)
			and vim.api.nvim_get_option_value("filetype", { buf = buf }) == "stim"
		then
			pcall(vim.treesitter.start, buf)
		end
	end

	if opts.highlight_measurements then
		require("stim-treesitter").setup()
		if opts.keymaps.show_info then
			vim.keymap.set("n", opts.keymaps.show_info, ":StimInfoTS<CR>", { desc = "Show Stim measurement info" })
		end
	end
end

return M
