return {
	"rcarriga/nvim-dap-ui",
	dependencies = {
		{ "mfussenegger/nvim-dap" },
		{
			"mfussenegger/nvim-dap-python",
			config = function()
				require("dap-python").setup("~/.local/share/virtualenvs/debugpy/bin/python")
			end,
		},
	},
}
