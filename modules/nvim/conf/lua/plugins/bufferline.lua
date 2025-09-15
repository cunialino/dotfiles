return {
	"akinsho/bufferline.nvim",
	dependencies = { { "nvim-tree/nvim-web-devicons" } },
	opts = {
		options = {
			offsets = {
				{
					filetype = "NvimTree",
					text = "File Explorer",
					highlight = "Directory",
					text_align = "center",
				},
			},
		},
	},
	event = "BufRead",
}
