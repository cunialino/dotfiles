return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.6",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-telescope/telescope-dap.nvim" },
		{ "nvim-telescope/telescope-live-grep-args.nvim" },
	},
	opts = {
		defaults = {
			vimgrep_arguments = {
				"rg",
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
				"--smart-case",
			},
		},
	},
	config = function(_, opts)
		local ts = require("telescope")
		ts.setup(opts)
		ts.load_extension("fzf")
		ts.load_extension("dap")
		ts.load_extension("live_grep_args")
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
					l = { builtins.live_grep, "RipGrep" },
				},
			},
		}
		wk.register(keys)
	end,
}
