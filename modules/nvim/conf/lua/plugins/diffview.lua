return {
	"sindrets/diffview.nvim",
	opts = {
		view = {
			merge_tool = {
				layout = "diff3_mixed",
				disable_diagnostics = true, -- Temporarily disable diagnostics for conflict buffers while in the view.
				winbar_info = true, -- See ':h diffview-config-view.x.winbar_info'
			},
		},
	},
}
