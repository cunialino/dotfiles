return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.6",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-telescope/telescope-dap.nvim" },
		{
			"nvim-telescope/telescope-live-grep-args.nvim",
		},
	},
	opts = function()
		local actions = require("telescope.actions")

		local lga_actions = require("telescope-live-grep-args.actions")

		local open_with_trouble_qf = function(prompt_bufnr)
			actions = require("telescope.actions")
			actions.smart_send_to_qflist(prompt_bufnr)
			require("trouble").open("qflist")
		end
		return {
			defaults = {
				prompt_prefix = " ",
				selection_caret = " ",
				-- open files in the first window that is an actual file.
				-- use the current window if no other window is available.
				get_selection_window = function()
					local wins = vim.api.nvim_list_wins()
					table.insert(wins, 1, vim.api.nvim_get_current_win())
					for _, win in ipairs(wins) do
						local buf = vim.api.nvim_win_get_buf(win)
						if vim.bo[buf].buftype == "" then
							return win
						end
					end
					return 0
				end,
				mappings = {
					i = {
						["<c-q>"] = open_with_trouble_qf,
						["<C-Down>"] = actions.cycle_history_next,
						["<C-Up>"] = actions.cycle_history_prev,
						["<C-f>"] = actions.preview_scrolling_down,
						["<C-u>"] = actions.preview_scrolling_up,
					},
					n = {
						["<c-q>"] = open_with_trouble_qf,
						["q"] = actions.close,
					},
				},
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
			extensions = {
				live_grep_args = {
					auto_quoting = true,
					mappings = {
						i = {
							["<C-k>"] = lga_actions.quote_prompt(),
						},
					},
				},
			},
		}
	end,
	config = function(_, opts)
		local ts = require("telescope")
		ts.setup(opts)
		ts.load_extension("fzf")
		ts.load_extension("dap")
		ts.load_extension("live_grep_args")
    ts.load_extension("notify")
		local builtins = require("telescope.builtin")
		local wk = require("which-key")
		local keys = {
			["<leader>"] = {
				f = {
					name = "Telescope",
					f = { builtins.find_files, "Files" },
					F = { builtins.find_files, "Files" },
					g = { builtins.git_files, "Git Files" },
					b = { builtins.buffers, "buffers" },
					s = { builtins.current_buffer_fuzzy_find, "Search" },
					R = { builtins.resume, "Resume" },
					t = { builtins.treesitter, "Treesitter" },
					P = { builtins.builtin, "Pickers" },
					r = { require("telescope").extensions.live_grep_args.live_grep_args, "RipGrep" },
					h = { builtins.help_tags, "Help" },
					o = { builtins.oldfiles, "Old Files" },
				},
			},
		}
		wk.register(keys)
	end,
}
