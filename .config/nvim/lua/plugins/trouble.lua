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
	keys = {
		{ "<leader>t", "", desc = "+Trouble" },
		{
			"<leader>td",
			function()
				require("trouble").toggle("diagnostics")
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>tl",
			function()
				require("trouble").toggle("lsp")
			end,
			desc = "LSP",
		},
		{
			"<leader>tq",
			function()
				require("trouble").toggle("qflist")
			end,
			desc = "QFList",
		},
		{
			"<leader>ts",
			function()
				require("trouble").toggle("symbols")
			end,
			desc = "Syms",
		},
	},
}
