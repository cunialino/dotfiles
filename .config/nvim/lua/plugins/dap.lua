return {
	"jay-babu/mason-nvim-dap.nvim",
	ft = { "python" },
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
		handlers = {
			function(config)
				-- all sources with no handler get passed here

				-- Keep original functionality
				require("mason-nvim-dap").default_setup(config)
			end,
			python = function(config)
				config.configurations = vim.tbl_deep_extend("force", config.configurations, {
					{ cwd = vim.loop.cwd() },
				})
				require("mason-nvim-dap").default_setup(config)
			end,
		},
	},
	keys = function()
		local wk = require("which-key")
		local keys = {
			["<leader>"] = {
				d = {
					name = "Debug",
					b = { "<cmd>lua require'dap'.toggle_breakpoint()<cr>", "Toggle Breakpoint" },
					c = { "<cmd>:lua require'dap'.continue()<cr>", "Continue debug" },
					o = { "<cmd>:lua require'dap'.step_over()<cr>", "Step over" },
					i = { "<cmd>:lua require'dap'.step_into()<cr>", "Step into" },
					t = { "<cmd>:lua require('dapui').toggle()<cr>", "Toggle ui" },
				},
			},
		}
		wk.register(keys)
	end,
}
