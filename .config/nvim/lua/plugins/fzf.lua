return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	init = function()
		local fzflua = require("fzf-lua")
		fzflua.register_ui_select()
	end,
	opts = {
		"fzf-native",
		keymap = {
			builtin = {},
			fzf = {
				["ctrl-d"] = "preview-page-down",
				["ctrl-f"] = "preview-page-up",
			},
		},
	},
	keys = function()
		local wk = require("which-key")
		local keys = {
			["<leader>"] = {
				f = {
					name = "FzfLua",
					f = { "<cmd>FzfLua files<cr>", "Find Files" },
					r = { "<cmd>FzfLua live_grep<cr>", "Live Grep" },
					b = { "<cmd>FzfLua buffers<cr>", "Buffers" },
					o = { "<cmd>FzfLua oldfiles<cr>", "Recent Files" },
					h = { "<cmd>FzfLua help_tags<cr>", "Help tags" },
				},
				g = {
					name = "Git",
					c = { "<cmd>FzfLua git_commits<cr>", "Show commits" },
					b = { "<cmd>FzfLua git_branches<cr>", "Show branches" },
				},
			},
		}
		wk.register(keys)
	end,
}
