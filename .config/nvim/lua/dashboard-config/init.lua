local db = require("dashboard")
db.setup({
	theme = "hyper",
	config = {
		header = require("dashboard-config.penguin-header"),

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
			{
				desc = " dotfiles",
				group = "Number",
				action = 'lua require("fzf-lua").files({ prompt_title = "Config Files", cwd = vim.fn.stdpath("config"), })',
				key = "d",
			},
			{
				desc = "Sessions",
				action = function()
					require("fzf-lua").fzf_exec("ls ~/.cache/nvim/session | cut -d '.' -f 1", {
						actions = {
							["default"] = function(selected, opts)
								vim.cmd("SessionLoad " .. selected[1])
							end,
						},
					})
				end,
				key = "s",
			},
		},
	},
	preview = {
		command = "lolcat -F 0.3",
		file_path = vim.fn.stdpath("config") .. "/lua/dashboard-config/penguin-header/preview",
		file_height = 16,
		file_width = 30,
	},
})
