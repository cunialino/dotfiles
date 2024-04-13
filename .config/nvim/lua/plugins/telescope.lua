return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.6",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-telescope/telescope-dap.nvim" },
	},
	config = function(_, opts)
		local ts = require("telescope")
		ts.setup(opts)
		ts.load_extension("fzf")
		ts.load_extension("dap")
		local builtins = require("telescope.builtin")
		local wk = require("which-key")
		local keys = {
			["<leader>"] = {
				t = {
					name = "Telescope",
					f = { builtins.find_files, "Files" },
					g = { builtins.git_files, "Git Files" },
					b = { builtins.buffers, "buffers" },
					s = { builtins.current_buffer_fuzzy_find, "Search" },
					r = { builtins.resume, "Resume" },
					t = { builtins.treesitter, "Treesitter" },
					B = { builtins.builtin, "Pickers" },
				},
			},
		}
		wk.register(keys)
	end,
}
