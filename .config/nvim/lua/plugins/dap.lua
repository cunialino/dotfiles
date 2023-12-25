return {
	"jay-babu/mason-nvim-dap.nvim",
	dependencies = {
		{
			"mfussenegger/nvim-dap",
			init = function()
				vim.fn.sign_define(
					"DapBreakpoint",
					{ text = " ", texthl = "@character.special", linehl = "", numhl = "@character.special" }
				)
			end,
		},
		{ "rcarriga/nvim-dap-ui", config = true },
	},
	opts = {
		ensure_installed = { "debugpy" },
		handlers = {},
	},
}
