return {
	"nvim-tree/nvim-tree.lua",
	cmd = "NvimTreeToggle",
	init = function()
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1
		vim.opt.termguicolors = true
	end,
	opts = {
		sort = {
			sorter = "case_sensitive",
		},
		view = { width = 25, side = "left" },
		renderer = {
			indent_markers = { enable = true, icons = { corner = "└ ", edge = "│ ", none = "  " } },
		},
		filters = {
			dotfiles = true,
		},
	},
}
