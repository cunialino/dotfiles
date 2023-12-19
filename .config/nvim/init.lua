require("ide-settings")
require("ide-settings/neovimSettings")
require("ide-settings/keybindings")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

local lazy = require("lazy")
lazy.setup({
	-- Syntax Highlighting and Visual Plugins
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("colorizer-config")
		end,
		event = "BufRead",
	},
	{
		"akinsho/nvim-bufferline.lua",
		dependencies = { { "nvim-tree/nvim-web-devicons" } },
		config = function()
			require("bufferline-config")
		end,
		event = "BufRead",
	},
	{
		"tamton-aquib/staline.nvim",
		config = function()
			require("staline-config")
		end,
		event = "BufRead",
	},
	{
		"glepnir/dashboard-nvim",
		event = "VimEnter",
		config = function()
			require("dashboard-config")
		end,
		dependencies = { { "nvim-tree/nvim-web-devicons" } },
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		config = function()
			require("blankline-config")
		end,
		event = "BufRead",
	},
	{
		"mhartington/formatter.nvim",
		config = function()
			require("formatter-config")
		end,
	},
	{
		"mfussenegger/nvim-lint",
		config = function()
			require("lint-config")
		end,
	},
	{
		"lewis6991/gitsigns.nvim",
		dependencies = { { "nvim-lua/plenary.nvim" } },
		event = "BufRead",
		config = function()
			require("gitsigns-config")
		end,
	},
	-- Colorschemes
	{ "shaunsingh/nord.nvim" },
	{
		"nvim-tree/nvim-tree.lua",
		cmd = "NvimTreeToggle",
		config = function()
			require("nvimtree-config")
		end,
	},
	{
		"folke/which-key.nvim",
		config = function()
			require("which-key-config")
		end,
	},
	{
		"terrortylor/nvim-comment",
		cmd = "CommentToggle",
		config = function()
			require("nvim_comment").setup()
		end,
	},
	{
		"ur4ltz/surround.nvim",
		config = function()
			require("surround").setup({ mappings_style = "sandwich" })
		end,
	},
	{
		"folke/trouble.nvim",
		dependencies = { { "nvim-tree/nvim-web-devicons" } },
		config = function()
			require("trouble-config")
		end,
	},
	{
		"mfussenegger/nvim-dap-python",
		config = function()
			require("dap-python").setup("~/.local/share/virtualenvs/debugpy/bin/python")
		end,
	},
	--this causes setup called twice
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { { "mfussenegger/nvim-dap" } },
		config = function()
			require("dapui").setup()
		end,
	},
	{ "tpope/vim-fugitive" },
	-- Terminal Integration
	{
		"akinsho/nvim-toggleterm.lua",
		config = function()
			require("toggleterm-config")
		end,
	},
	{
		"ibhagwan/fzf-lua",
		-- optional for icon support
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local fzflua = require("fzf-lua")
			fzflua.setup({})
			fzflua.register_ui_select()
		end,
	},

	--
	-- Tree-Sitter
	{
		"nvim-treesitter/nvim-treesitter",
		event = "BufWinEnter",
		build = ":TSUpdate",
		config = function()
			require("treesitter-config")
		end,
		dependencies = {
			{ "RRethy/nvim-treesitter-endwise" },
			{ "RRethy/nvim-treesitter-textsubjects" },
		},
	},
	--
	--
	--  -- LSP and Autocomplete
	--  schema store has to be before lspconfig!!!
	{
		"neovim/nvim-lspconfig",
		config = function()
			require("language-servers")
		end,
		dependencies = {
			{ "b0o/schemastore.nvim" },
			{ "williamboman/nvim-lsp-installer" },
		},
	},
	-- Cmp block
	{
		"hrsh7th/nvim-cmp",
		config = function()
			require("cmp-config")
		end,
		dependencies = {
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
			{ "hrsh7th/cmp-vsnip" },
			{ "onsails/lspkind-nvim" },
			{
				"ray-x/lsp_signature.nvim",
				config = function()
					require("lsp_signature").setup({})
				end,
			},
		},
	},
	{
		"windwp/nvim-autopairs",
		config = function()
			require("autopairs-config")
		end,
	},
	{
		"hrsh7th/vim-vsnip",
		config = function()
			require("vsnip-config")
		end,
		dependencies = {
			{ "hrsh7th/vim-vsnip-integ" },
			{ "rafamadriz/friendly-snippets" },
		},
	},

	{
		"phaazon/hop.nvim",
		branch = "v2", -- optional but strongly recommended
		config = function()
			-- you can configure Hop the way you like here; see :h hop-config
			require("hop").setup()
		end,
	},
	{ "goerz/jupytext.vim" },
	{
		"hkupty/iron.nvim",
		config = function()
			require("iron-config")
		end,
	},
})
vim.cmd("colorscheme nord")
