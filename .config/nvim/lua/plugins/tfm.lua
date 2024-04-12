return {
	"rolv-apneseth/tfm.nvim",
	lazy = false,
	opts = {
		file_manager = "yazi",
		replace_netrw = true,
		enable_cmds = false,
		ui = {
			border = "rounded",
			height = 0.75,
			width = 0.75,
			x = 0.5,
			y = 0.5,
		},
	},
	config = true,
	keys = {
		{
			"<leader>e",
			function()
				require("tfm").open()
			end,
			desc = "TFM",
		}
	},
}
