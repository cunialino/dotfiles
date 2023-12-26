return {
	"phaazon/hop.nvim",
	branch = "v2",
	config = true,
	keys = function()
		local wk = require("which-key")
		wk.register({

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
)
	end,
}
