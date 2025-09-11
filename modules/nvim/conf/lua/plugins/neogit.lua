return {
	"NeogitOrg/neogit",
	dependencies = {
		"nvim-lua/plenary.nvim", -- required
		"sindrets/diffview.nvim", -- optional - Diff integration

		-- Only one of these is needed, not both.
		"nvim-telescope/telescope.nvim", -- optional
	},
	config = true,
	keys = function()
		local neogit = require("neogit")
		local keys = {
			{ "<leader>g", "", desc = "+Git" },
			{ "<leader>gn", neogit.open, desc = "Open Neogit" },
		}
		return keys
	end,
}
