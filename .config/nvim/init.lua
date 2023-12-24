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
	{ import = "plugins" },
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
				"hrsh7th/vim-vsnip",
				init = function()
					vim.g.vsnip_snippet_dir = "~/.config/nvim/.vsnip/"
				end,
				dependencies = {
					{ "hrsh7th/vim-vsnip-integ" },
					{ "rafamadriz/friendly-snippets" },
				},
			},
			{
				"ray-x/lsp_signature.nvim",
				config = function()
					require("lsp_signature").setup({})
				end,
			},
		},
	},
})
vim.cmd("colorscheme nord")
