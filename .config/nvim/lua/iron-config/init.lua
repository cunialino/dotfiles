local iron = require("iron.core")
local view = require("iron.view")

iron.setup({
	config = {
		should_map_plug = false,
		scratch_repl = true,
		repl_definition = {
			python = {
				command = { "jupyter-console" },
				format = require("iron.fts.common").bracketed_paste,
			},
		},
		repl_open_cmd = view.center("80%", 20),
	},
	keymaps = {
		send_motion = "<C-s>",
		visual_send = "<C-s>",
	},
})
