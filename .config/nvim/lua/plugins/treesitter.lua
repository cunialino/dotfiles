return {
	"nvim-treesitter/nvim-treesitter",
	event = "BufWinEnter",
	build = ":TSUpdate",
	dependencies = {
		{ "RRethy/nvim-treesitter-endwise" },
		{ "RRethy/nvim-treesitter-textsubjects" },
	},
}
