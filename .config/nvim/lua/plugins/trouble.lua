return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		modes = {
			lsp = {
				mode = "lsp",
				focus = false,
				win = { position = "right" },
			},
		},
	},
	config = true,
	keys = function()
		local wk = require("which-key")
		wk.register({
			["<leader>"] = {
				t = {
					name = "Diagnostics",
					d = {
						function()
							require("trouble").toggle("diagnostics")
						end,
						"Diagnostics",
					},
					l = {
						function()
							require("trouble").toggle("lsp")
						end,
						"LSP",
					},
					q = {
						function()
							require("trouble").toggle("qflist")
						end,
						"QFList",
					},
					s = {
						function()
							require("trouble").toggle("symbols")
						end,
						"Syms",
					},
				},
			},
		})
	end,
}
