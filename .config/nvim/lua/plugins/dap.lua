local base_daps_dir = vim.fn.stdpath("data") .. "/mason/bin/"
return {
	"mfussenegger/nvim-dap",
	init = function()
		vim.fn.sign_define(
			"DapBreakpoint",
			{ text = " ", texthl = "@character.special", linehl = "", numhl = "@character.special" }
		)
	end,
	dependencies = {
		{ "jay-babu/mason-nvim-dap.nvim" },
		{ "nvim-neotest/nvim-nio" },
		{ "rcarriga/nvim-dap-ui", config = true },
	},
	opts = {
		debugpy = {
			adapter = function(cb, config)
				if config.request == "attach" then
					local port = (config.connect or config).port
					local host = (config.connect or config).host or "127.0.0.1"
					cb({
						type = "server",
						port = assert(port, "`connect.port` is required for a python `attach` configuration"),
						host = host,
						options = {
							source_filetype = "python",
						},
					})
				else
					cb({
						type = "executable",
						command = base_daps_dir .. "debugpy-adapter",
						options = {
							source_filetype = "python",
						},
					})
				end
			end,
			configuration = {
				{
					type = "python",
					request = "launch",
					name = "Launch file",
					program = "${file}",
          pythonPath = "python",
				},
			},
		},
	},
	config = function(_, opts)
		local dap = require("dap")
		local daps_by_ft = require("tools").tool_by_type("dap")
		for ft, current_dap in pairs(daps_by_ft) do
			dap.adapters[ft] = opts[current_dap[1]].adapter
			dap.configurations[ft] = opts[current_dap[1]].configuration
		end
	end,
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
