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
	{ "goerz/jupytext.vim" },
	{ "glepnir/dbsession.nvim", cmd = { "SessionSave", "SessionDelete", "SessionLoad" } },
	{ "phaazon/hop.nvim", branch = "v2" },
	{ "windwp/nvim-autopairs", config = true },
	{ "terrortylor/nvim-comment", cmd = "CommentToggle", config = true },
	{
		"ur4ltz/surround.nvim",
		opts = {
			mappings_style = "sandwich",
		},
	},
	{ "tpope/vim-fugitive" },
	{ "akinsho/nvim-toggleterm.lua" },
	{ import = "plugins" },
	{ import = "plugins.lsp" },
}, {
	checker = {
		enabled = true,
		notify = false,
	},
	change_detection = {
		notify = false,
	},
})
