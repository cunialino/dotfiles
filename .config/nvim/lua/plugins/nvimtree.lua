local gwidth = vim.api.nvim_list_uis()[1].width
local gheight = vim.api.nvim_list_uis()[1].height
local width = 60
local height = 20
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
		view = {
			width = 25,
			float = {
				enable = true,
				open_win_config = {
					relative = "editor",
					width = width,
					height = height,
					row = (gheight - height) * 0.4,
					col = (gwidth - width) * 0.5,
				},
			},
		},
		renderer = {
			indent_markers = { enable = true, icons = { corner = "└ ", edge = "│ ", none = "  " } },
		},
		filters = {
			dotfiles = true,
		},
	},
}
