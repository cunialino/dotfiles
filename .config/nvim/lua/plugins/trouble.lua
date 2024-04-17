return {
	"folke/trouble.nvim",
	branch = "dev",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = true,
	keys = function()
		local wk = require("which-key")
		wk.register({
			["<leader>"] = {
				T = {
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
