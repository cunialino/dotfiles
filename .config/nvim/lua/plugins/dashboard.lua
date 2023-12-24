return {
	"glepnir/dashboard-nvim",
	event = "VimEnter",
	opts = {
		theme = "hyper",
		config = {
			header = require("penguin-header"),

			shortcut = {
				{ desc = "󰊳 Update", group = "@property", action = "Lazy sync", key = "u" },
				{
					icon = " ",
					icon_hl = "@variable",
					desc = "Files",
					group = "Label",
					action = "FzfLua files",
					key = "f",
				},
				{
					desc = " Git config",
					group = "@propery",
					action = "lua require('toggleterm.terminal').Terminal:new({cmd='lazygit --git-dir=$HOME/builds/dotfiles --work-tree=$HOME', direction = 'float'}):toggle()",
					key = "g",
				},
				--{
				--	desc = " dotfiles",
				--	group = "Number",
				--	action = require("custom-fzf").search_config_files,
				--	key = "d",
				--},
				--{
				--	desc = "󰑓 Sessions",
				--	action = require("custom-fzf").load_sessions,
				--	key = "s",
				--},
			},
		},
		preview = {
			command = "lolcat -F 0.3",
			file_path = vim.fn.stdpath("config") .. "/lua/penguin-header/preview",
			file_height = 16,
			file_width = 30,
		},
	},
	dependencies = { { "nvim-tree/nvim-web-devicons" } },
}
