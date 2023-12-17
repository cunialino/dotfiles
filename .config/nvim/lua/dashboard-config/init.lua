local db = require("dashboard")
db.setup({
	theme = "hyper",
	config = {
		week_header = {
			enable = true,
		},
		shortcut = {
			{ desc = "󰊳 Update", group = "@property", action = "PackerSync", key = "u" },
			{
				icon = " ",
				icon_hl = "@variable",
				desc = "Files",
				group = "Label",
				action = "Telescope find_files",
				key = "f",
			},
			{
				desc = " Git config",
				group = "@propery",
				action = "lua require('toggleterm.terminal').Terminal:new({cmd='lazygit --git-dir=$HOME/builds/dotfiles --work-tree=$HOME', direction = 'float'}):toggle()",
				key = "g",
			},
			{
				desc = " dotfiles",
				group = "Number",
				action = 'lua require("telescope.builtin").find_files({ prompt_title = "Config Files", cwd = vim.fn.stdpath("config"), })',
				key = "d",
			},
		},
	},
	project = { enable = true, limit = 8 },
})
