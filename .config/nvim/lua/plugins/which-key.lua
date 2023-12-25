return {
	"folke/which-key.nvim",
	event = "VimEnter",
	config = function()
		local wk = require("which-key")

		local keys = {
			["<leader>"] = {
				x = { ":bdelete<cr>", "Close Buffer" },
				X = { ":bdelete!<cr>", "Force Close Buffer" },
				q = { ":wq<cr>", "Save and Quit" },
				Q = { ":q!<cr>", "Force Quit" },
				w = { ":w<cr>", "Write" },
				L = { ":Lazy<cr>", "Lazy" },
				e = { ":NvimTreeToggle<cr>", "File Explorer" },
				g = {
					name = "Git",
					l = {
						"<cmd>lua require('toggleterm.terminal').Terminal:new({cmd='lazygit', direction = 'float'}):toggle()<cr>",
						"Toggle lazygit",
					},
					L = {
						":lua require('toggleterm.terminal').Terminal:new({cmd='lazygit --git-dir=$HOME/builds/dotfiles --work-tree=$HOME', direction = 'float'}):toggle()<cr>",
						"Toggle lazyconfig",
					},
				},
				d = {
					name = "Debug",
					b = { "<cmd>lua require'dap'.toggle_breakpoint()<cr>", "Toggle Breakpoint" },
					c = { "<cmd>:lua require'dap'.continue()<cr>", "Continue debug" },
					o = { "<cmd>:lua require'dap'.step_over()<cr>", "Step over" },
					i = { "<cmd>:lua require'dap'.step_into()<cr>", "Step into" },
					t = { "<cmd>:lua require('dapui').toggle()<cr>", "Toggle ui" },
				},
				h = { ":Dashboard<cr>", "Dashboard" },
				u = {
					name = "Utils",
					t = { "<cmd>ToggleTerm<cr>", "Toggle term" },
					f = {
						"<cmd>lua require('toggleterm.terminal').Terminal:new({direction = 'float'}):toggle()<cr>",
						"Toggle float",
					},
					l = {
						"<cmd>lua require('toggleterm.terminal').Terminal:new({cmd='lazygit', direction = 'float'}):toggle()<cr>",
						"Toggle lazygit",
					},
				},
				o = { ":only<cr>", "Only" },
				["/"] = { ":CommentToggle<cr>", "Toggle Comment" },
			},
			f = {
				"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = false })<cr>",
				"Char forward",
			},
			F = {
				"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = false })<cr>",
				"Char backward",
			},
			S = {
				"<cmd>lua require'hop'.hint_patterns()<cr>",
				"Pattern search",
			},
		}
		wk.register(keys)
	end,
}
