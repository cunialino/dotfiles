return {
	"lewis6991/gitsigns.nvim",
	dependencies = { { "nvim-lua/plenary.nvim" } },
	event = "BufRead",
	opts = {
		numhl = false,
		linehl = false,
		watch_gitdir = { interval = 1000 },
		sign_priority = 6,
		update_debounce = 200,
		status_formatter = nil,
	},
	keys = function()
		local gs = require("gitsigns")
		local keys = {
			{ "<leader>g", "", desc = "+Git" },
			{ "<leader>gD", gs.diffthis, desc = "Diff this" },
			{ "<leader>gp", gs.preview_hunk, desc = "Preview hunk" },
			{ "<leader>gb", gs.toggle_current_line_blame, desc = "Toggle current line blame" },
			{ "<leader>gs", gs.stage_hunk, desc = "Stage hunk" },
			{ "<leader>gr", gs.reset_hunk, desc = "Stage Reset Hunk" },
			{ "<leader>gR", gs.reset_buffer, desc = "Stage Reset Hunk" },
			{ "<leader>gS", gs.stage_buffer, desc = "Stage buffer" },
			{ "<leader>gu", gs.undo_stage_hunk, desc = "Undo stage hunk" },
			{ "]h", gs.next_hunk, desc = "Next Hunk" },
			{ "[h", gs.prev_hunk, desc = "Previews Hunk" },
		}
		return keys
	end,
}
