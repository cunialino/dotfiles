return {
	"lewis6991/gitsigns.nvim",
	dependencies = { { "nvim-lua/plenary.nvim" } },
	event = "BufRead",
	opts = {
		signs = {
			add = { hl = "GitSignsAdd", text = "▎", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
			change = {
				hl = "GitSignsChange",
				text = "▎",
				numhl = "GitSignsChangeNr",
				linehl = "GitSignsChangeLn",
			},
			delete = {
				hl = "GitSignsDelete",
				text = "▎",
				numhl = "GitSignsDeleteNr",
				linehl = "GitSignsDeleteLn",
			},
			topdelete = {
				hl = "GitSignsDelete",
				text = "▎",
				numhl = "GitSignsDeleteNr",
				linehl = "GitSignsDeleteLn",
			},
			changedelete = {
				hl = "GitSignsChange",
				text = "▎",
				numhl = "GitSignsChangeNr",
				linehl = "GitSignsChangeLn",
			},
		},
		numhl = false,
		linehl = false,
		watch_gitdir = { interval = 1000 },
		sign_priority = 6,
		update_debounce = 200,
		status_formatter = nil,
	},
	keys = function()
		local wk = require("which-key")
    local gs = require("gitsigns")
		local keys = {
			["<leader>"] = {
				g = {
					name = "Git",
					D = { gs.diffthis, "Diff this" },
          p = { gs.preview_hunk, "Preview hunk"},
          b = {gs.toggle_current_line_blame, "Toggle current line blame"},
          s = { gs.stage_hunk, "Stage hunk" },
          S = { gs.stage_buffer, "Stage buffer" },
          u = { gs.undo_stage_hunk, "Undo stage hunk" },
				},
			},
      ["]h"] = { gs.next_hunk, "Next Hunk" },
      ["[h"] = { gs.prev_hunk, "Previews Hunk" },
		}
    wk.register(keys)
	end,
}
