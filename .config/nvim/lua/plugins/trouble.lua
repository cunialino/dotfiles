return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = true,
	keys = function()
		local wk = require("which-key")
		wk.register({
			["<leader>"] = {
				D = {
					name = "Diagnostics",
					o = { vim.diagnostic.open_float, "Line diagnostics" },
					d = {
						function()
							require("trouble").toggle("document_diagnostics")
						end,
						"Document Diagnostics",
					},
					w = {
						function()
							require("trouble").toggle("workspace_diagnostics")
						end,
						"Workspace Diagnostics",
					},
				},
			},
		})
	end,
}
