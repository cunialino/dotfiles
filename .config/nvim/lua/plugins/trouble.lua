return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	init = function()
		vim.diagnostic.handlers["trouble"] = {
			show = function()
				require("trouble").toggle("workspace_diagnostics")
			end,
			hide = require("trouble").close,
		}
	end,
	opts = {},
}
