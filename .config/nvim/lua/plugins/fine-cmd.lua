return {
	"VonHeikemen/fine-cmdline.nvim",
	dependencies = {
		{ "MunifTanjim/nui.nvim" },
	},
	config = true,
	keys = {
		{ ":", "<cmd>FineCmdline<CR>", desc = "FineCmd" },
	},
}
