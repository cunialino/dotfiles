return {
	"rolv-apneseth/tfm.nvim",
	lazy = false,
	opts = {
		-- TFM to use
		-- Possible choices: "ranger" | "nnn" | "lf" | "vifm" | "yazi" (default)
		file_manager = "yazi",
		-- Replace netrw entirely
		-- Default: false
		replace_netrw = true,
		enable_cmds = false,
		-- Custom keybindings only applied within the TFM buffer
		-- Default: {}
		keybindings = {
			["<ESC>"] = "q",
			-- Override the open mode (i.e. vertical/horizontal split, new tab)
			-- Tip: you can add an extra `<CR>` to the end of these to immediately open the selected file(s) (assuming the TFM uses `enter` to finalise selection)
			["<C-v>"] = "<C-\\><C-O>:lua require('tfm').set_next_open_mode(require('tfm').OPEN_MODE.vsplit)<CR>",
			["<C-x>"] = "<C-\\><C-O>:lua require('tfm').set_next_open_mode(require('tfm').OPEN_MODE.split)<CR>",
			["<C-t>"] = "<C-\\><C-O>:lua require('tfm').set_next_open_mode(require('tfm').OPEN_MODE.tabedit)<CR>",
		},
		-- Customise UI. The below options are the default
		ui = {
			border = "rounded",
			height = 0.75,
			width = 0.75,
			x = 0.5,
			y = 0.5,
		},
	},
	config = true,
	keys = {
		{
			"<leader>e",
			function()
				require("tfm").open()
			end,
			desc = "TFM",
		},
		{
			"<leader>mh",
			function()
				local tfm = require("tfm")
				tfm.open(nil, tfm.OPEN_MODE.split)
			end,
			desc = "TFM - horizontal split",
		},
		{
			"<leader>mv",
			function()
				local tfm = require("tfm")
				tfm.open(nil, tfm.OPEN_MODE.vsplit)
			end,
			desc = "TFM - vertical split",
		},
		{
			"<leader>mt",
			function()
				local tfm = require("tfm")
				tfm.open(nil, tfm.OPEN_MODE.tabedit)
			end,
			desc = "TFM - new tab",
		},
	},
}
