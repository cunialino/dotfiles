local git_icons = require("icons").git
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
		git = {

			status = {
				prompt = "GitStatus❯ ",
				cmd = "git -c color.status=false status -su",
				file_icons = true,
				git_icons = true,
				color_icons = true,
				previewer = "git_diff",
				preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS",
			},
			icons = {
				["M"] = { icon = git_icons.unstaged, color = "yellow" },
				["D"] = { icon = git_icons.deleted, color = "red" },
				["A"] = { icon = git_icons.deleted, color = "green" },
				["R"] = { icon = git_icons.renamed, color = "yellow" },
				["C"] = { icon = "C", color = "yellow" },
				["T"] = { icon = "T", color = "magenta" },
				["?"] = { icon = git_icons.untracked, color = "magenta" },
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
					F = {
						name = "Fzf",
						C = { "<cmd>FzfLua git_commits<cr>", "Show commits" },
						B = { "<cmd>FzfLua git_branches<cr>", "Show branches" },
						c = { "<cmd>FzfLua git_bcommits<cr>", "Show commits" },
						s = { "<cmd> FzfLua git_status<cr>", "Show status" },
					},
				},
			},
		}
		wk.register(keys)
	end,
}
