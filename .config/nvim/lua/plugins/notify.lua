return {
	"rcarriga/nvim-notify",
	event = "VeryLazy",
	init = function()
		vim.notify = require("notify")
		vim.diagnostic.open_float = function()
			local line_diagno = vim.lsp.diagnostic.get_line_diagnostics()
			for _, v in pairs(line_diagno) do
				vim.notify(v["message"], 2, { title = string.format("%s: %s", v["source"], v["code"]), timeout = 2000 })
			end
		end
	end,
	keys = function()
		local wk = require("which-key")
		wk.register({
			["<leader>"] = {
				n = {
					name = "Notify",
					d = {
						function()
							require("notify").dismiss({ silent = true, pending = true })
						end,
						"Dismiss all Notifications",
					},
				},
			},
		})
	end,

	opts = {
		timeout = 3000,
		max_height = function()
			return math.floor(vim.o.lines * 0.75)
		end,
		max_width = function()
			return math.floor(vim.o.columns * 0.75)
		end,
		on_open = function(win)
			vim.api.nvim_win_set_config(win, { zindex = 100 })
		end,
	},
}
