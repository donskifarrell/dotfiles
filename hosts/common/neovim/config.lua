require'nvim-web-devicons'.setup {
    default = true
}

require('nvim-treesitter.configs').setup {
    ensure_installed = {},
    highlight = {
        enable = true
    },
    indent = {
        enable = true
    },
    rainbow = {
        enable = true,
        extended_mode = true,
        -- prevents lagging in large files
        max_file_lines = 1000
    },
    autotag = {
        enable = true
    }
}

require('lualine').setup {
    options = {
        icons_enabled = true,
        theme = 'dracula'
    }
}
require("bufferline").setup {}

require'nvim-tree'.setup()
require'colorizer'.setup()
require("which-key").setup()
