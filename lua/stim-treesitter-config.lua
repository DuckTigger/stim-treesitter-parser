-- Stim Tree-sitter configuration (auto-generated)
local M = {}

function M.setup(opts)
    opts = opts or {}
    local defaults = {
        highlight_measurements = true,
        keymaps = { show_info = "<leader>si" }
    }
    opts = vim.tbl_deep_extend("force", defaults, opts)
    
    local ok, parsers = pcall(require, "nvim-treesitter.parsers")
    if not ok then
        vim.notify("nvim-treesitter not found", vim.log.levels.ERROR)
        return
    end
    
    local parser_config = parsers.get_parser_configs()
    parser_config.stim = {
        install_info = {
            url = "https://github.com/DuckTigger/stim-treesitter-parser",
            files = {"src/parser.c"},
            branch = "main",
            generate_requires_npm = false,
            requires_generate_from_grammar = false,
        },
        filetype = "stim",
    }
    
    vim.filetype.add({ extension = { stim = "stim" } })
    
    if opts.highlight_measurements then
        require('stim-treesitter').setup()
        if opts.keymaps.show_info then
            vim.keymap.set('n', opts.keymaps.show_info, ':StimInfoTS<CR>', 
                { desc = 'Show Stim measurement info' })
        end
    end
end

return M
