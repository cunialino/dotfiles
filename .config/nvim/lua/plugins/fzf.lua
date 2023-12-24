return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	init = function()
		local fzflua = require("fzf-lua")
		fzflua.register_ui_select()
	end,
}
