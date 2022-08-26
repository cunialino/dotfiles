require("ide-settings")
require("ide-settings/neovimSettings")
require("ide-settings/keybindings")
local packer = require("packer")
packer.init({
  snapshot_path = ".snapshots", -- Default save directory for snapshots
})
packer.startup(function()
  use("wbthomason/packer.nvim")
  -- Syntax Highlighting and Visual Plugins
  use({ "norcalli/nvim-colorizer.lua", config = "require'colorizer-config'", event = "BufRead" })
  use({
    "akinsho/nvim-bufferline.lua",
    requires = "kyazdani42/nvim-web-devicons",
    config = 'require"bufferline-config"',
    event = "BufRead",
  })
  use({ "tamton-aquib/staline.nvim", config = "require'staline-config'", event = "BufRead" })
  use({ "glepnir/dashboard-nvim", config = "require('dashboard-config')" })
  use({
    "lukas-reineke/indent-blankline.nvim",
    config = "require'blankline-config'",
    event = "BufRead",
  })
  use({ "folke/zen-mode.nvim", config = 'require("zen-mode-config")' })
  use({ "folke/twilight.nvim", config = "require('twilight-config')" })
  use({
    "lewis6991/gitsigns.nvim",
    requires = { "nvim-lua/plenary.nvim" },
    event = "BufRead",
    config = "require('gitsigns-config')",
  })
  use({ "kyazdani42/nvim-web-devicons", event = "BufRead" })
  -- Colorschemes
  use({ "shaunsingh/nord.nvim" })
  use({ "kyazdani42/nvim-tree.lua", cmd = "NvimTreeToggle", config = "require'nvimtree-config'" })
  use({ "folke/which-key.nvim", config = "require'which-key-config'" })
  use({
    "terrortylor/nvim-comment",
    cmd = "CommentToggle",
    config = "require('nvim_comment').setup()",
  })
  use({ "jose-elias-alvarez/null-ls.nvim", config = "require'null-ls-config'" })
  use({
    "ur4ltz/surround.nvim",
    config = function()
      require("surround").setup({ mappings_style = "sandwich" })
    end,
  })
  use({ "andweeb/presence.nvim", event = "BufRead", config = 'require("presence-config")' })
  use({
    "folke/trouble.nvim",
    requires = "kyazdani42/nvim-web-devicons",
    config = "require'trouble-config'",
  })
  use({ "mfussenegger/nvim-dap" })
  use({
    "mfussenegger/nvim-dap-python",
    config = "require('dap-python').setup('~/.local/share/virtualenvs/debugpy/bin/python')",
  })
  --this causes setup called twice
  use({
    "rcarriga/nvim-dap-ui",
    requires = { "mfussenegger/nvim-dap" },
    config = "require('dapui').setup()",
  })
  use({ "tpope/vim-fugitive" })
  use({
    "iamcco/markdown-preview.nvim",
    run = "cd app && npm install",
    config = "require('markdown-prev-config')",
    ft = { "markdown" },
  })
  -- Terminal Integration
  use({ "akinsho/nvim-toggleterm.lua", config = 'require"toggleterm-config"' })

  -- Navigation
  use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })
  use({ "nvim-telescope/telescope-ui-select.nvim" })
  use({
    "nvim-telescope/telescope.nvim",
    requires = {
      { "nvim-lua/popup.nvim" },
      { "nvim-lua/plenary.nvim" },
    },
    cmd = "Telescope",
    config = "require'telescope-config'",
  })
  use({ "mfussenegger/nvim-lint", config = "require'lint-config'" })

  --
  -- Tree-Sitter
  use({
    "nvim-treesitter/nvim-treesitter",
    event = "BufWinEnter",
    run = ":TSUpdate",
    config = "require'treesitter-config'",
  })
  use({ "RRethy/nvim-treesitter-endwise", after = "nvim-treesitter" })
  use({ "RRethy/nvim-treesitter-textsubjects", after = "nvim-treesitter" })
  --
  --
  --  -- LSP and Autocomplete
  --  schema store has to be before lspconfig!!!
  use({ "b0o/schemastore.nvim" })
  use({ "neovim/nvim-lspconfig", config = "require'language-servers'" })
  use({ "williamboman/nvim-lsp-installer" })
  -- Cmp block
  use({ "onsails/lspkind-nvim" })
  use({
    "hrsh7th/nvim-cmp",
    config = function()
      require("cmp-config")
    end,
  })
  use({ "windwp/nvim-autopairs", after = "nvim-cmp", config = "require'autopairs-config'" })
  use({ "hrsh7th/cmp-nvim-lsp" })
  use({ "hrsh7th/cmp-buffer", after = "nvim-cmp" })
  use({ "hrsh7th/cmp-path", after = "nvim-cmp" })
  use({ "hrsh7th/cmp-vsnip", after = "nvim-cmp" })
  use({ "hrsh7th/vim-vsnip", after = "nvim-cmp", config = "require('vsnip-config')" })
  use({ "hrsh7th/vim-vsnip-integ", after = "nvim-cmp" })
  use({ "rafamadriz/friendly-snippets" })

  -- DB plugins
  use({
    "tpope/vim-dadbod",
    requires = {
      "kristijanhusak/vim-dadbod-ui",
    },
    setup = function()
      vim.g.db_ui_save_location = "~/.config/db_ui"
    end,
  })
  use({
    "phaazon/hop.nvim",
    branch = "v2", -- optional but strongly recommended
    config = function()
      -- you can configure Hop the way you like here; see :h hop-config
      require("hop").setup()
    end,
  })
  use({ "wakatime/vim-wakatime" })
  use({ "untitled-ai/jupyter_ascending.vim" })
  use({ "lervag/vimtex", config = "require'vimtex-config'" })
end)
vim.cmd("colorscheme nord")
