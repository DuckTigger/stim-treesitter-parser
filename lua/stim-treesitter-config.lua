-- Stim Tree-sitter configuration
-- Parser registration is also handled by plugin/stim-treesitter.lua at load time,
-- but we register here too as a fallback for unusual loading orders.
local M = {}

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
	require("stim-treesitter-register").setup()

	-- Enable treesitter highlighting for stim buffers.
	-- nvim-treesitter's master highlight module only activates for filetypes it
	-- knew about at initialisation time, and the main branch has no highlight
	-- module at all, so we start the built-in highlighter explicitly per-buffer.
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
