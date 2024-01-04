return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	init = function()
		vim.lsp.buf.references = function()
			require("trouble").toggle("lsp_references")
		end
		vim.lsp.buf.definition = function()
			require("trouble").toggle("lsp_definitions")
		end
	end,
	config = true,
	keys = function()
		local wk = require("which-key")
		wk.register({
			["<leader>"] = {
				D = {
					name = "Diagnostics",
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
