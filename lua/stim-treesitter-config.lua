-- Stim Tree-sitter configuration
-- Parser registration is handled by plugin/stim-treesitter.lua at load time.
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

	-- Parser registration and filetype mapping are handled by plugin/stim-treesitter.lua
	-- which runs at load time. Nothing to do here.

	if opts.highlight_measurements then
		require("stim-treesitter").setup()
		if opts.keymaps.show_info then
			vim.keymap.set("n", opts.keymaps.show_info, ":StimInfoTS<CR>", { desc = "Show Stim measurement info" })
		end
	end
end

return M
