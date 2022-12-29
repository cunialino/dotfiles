require 'nvim-treesitter.install'.compilers = { "gcc" }

require 'nvim-treesitter.configs'.setup {
  enabled = true,
  ensure_installed = "all",
  ignore_install = {},
  indent = { enable = true },
  highlight = { enable = true },
  autotag = { enable = true },
  endwise = { enable = true },
  rainbow = { enable = true, extended_mode = false, disable = { "html" } },
  textsubjects = {
    enable = true,
    prev_selection = ',', -- (Optional) keymap to select the previous selection
    keymaps = {
      ['.'] = 'textsubjects-smart',
      [';'] = 'textsubjects-container-outer',
      ['i;'] = 'textsubjects-container-inner'
    }
  }
}
