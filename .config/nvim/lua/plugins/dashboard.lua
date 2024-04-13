return {
	"glepnir/dashboard-nvim",
	event = "VimEnter",
	opts = {
		theme = "doom",
		config = {
			header = require("penguin-header"), --your header
			center = {
				{
					icon = "󰊳 ",
					icon_hl = "@constant",
					desc = "Update Plugins with Lazy",
					desc_hl = "@comment",
					action = "Lazy sync",
					key_hl = "@function",
					key = "u",
				},
				{
					icon = " ",
					icon_hl = "@constant",
					desc_hl = "@comment",
					key_hl = "@function",
					desc = "Search within gitfiles",
					group = "Number",
					action = 'lua require("telescope.builtin").git_files()',
					key = "d",
				},
				{
					icon = " ",
					icon_hl = "@constant",
					desc = "Search Old File",
					desc_hl = "@comment",
					action = 'lua require("telescope.builtin").oldfiles()',
					key_hl = "@function",
					key = "o",
				},
			},
			footer = {
				" ",
				"“The prize is in the pleasure of finding the thing out, ",
				"the kick in the discovery, the observation that other people use it.",
				"Those are the real things, the honors are unreal to me.”",
				"― Richard Feynman",
			}, --your footer
		},
		-- preview = {
		-- 	command = "lolcat -F 0.3",
		-- 	file_path = vim.fn.stdpath("config") .. "/lua/penguin-header/preview",
		-- 	file_height = 16,
		-- 	file_width = 30,
		-- },
	},
	dependencies = { { "nvim-tree/nvim-web-devicons" }, { "nvim-telescope/telescope.nvim"} },
}
