return {
	"akinsho/nvim-toggleterm.lua",
	keys = function()
		local wk = require("which-key")
		wk.register({
			["<leader>"] = {
				g = {
					name = "Git",
					l = {
						"<cmd>lua require('toggleterm.terminal').Terminal:new({cmd='lazygit', direction = 'float'}):toggle()<cr>",
						"Toggle lazygit",
					},
					L = {
						":lua require('toggleterm.terminal').Terminal:new({cmd='lazygit --git-dir=$HOME/builds/dotfiles --work-tree=$HOME', direction = 'float'}):toggle()<cr>",
						"Toggle lazyconfig",
					},
				},
				u = {
					name = "Utils",
					t = { "<cmd>ToggleTerm<cr>", "Toggle term" },
					f = {
						"<cmd>lua require('toggleterm.terminal').Terminal:new({direction = 'float'}):toggle()<cr>",
						"Toggle float",
					},
				},
			},
		})
	end,
}
