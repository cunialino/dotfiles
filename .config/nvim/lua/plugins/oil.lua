return {
	"stevearc/oil.nvim",
	opts = {},
	-- Optional dependencies
	keys = { {
		"<leader>e",
		function()
			require("oil").open()
		end,
		desc = "Oil",
	} },
	dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
}
