local git_icons = require("icons").git
return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	init = function()
		local fzflua = require("fzf-lua")
		fzflua.register_ui_select()
		vim.lsp.buf.references = fzflua.lsp_references
		vim.lsp.buf.definition = fzflua.lsp_definitions
		vim.lsp.buf.declaration = fzflua.lsp_declarations
	end,
	opts = {
		"fzf-native",
		keymap = {
			builtin = {},
			fzf = {
				["ctrl-d"] = "preview-page-down",
				["ctrl-f"] = "preview-page-up",
			},
		},
		git = {
			icons = {
				["M"] = { icon = git_icons.unstaged, color = "yellow" },
				["D"] = { icon = git_icons.deleted, color = "red" },
				["A"] = { icon = git_icons.deleted, color = "green" },
				["R"] = { icon = git_icons.renamed, color = "yellow" },
				["C"] = { icon = "C", color = "yellow" },
				["T"] = { icon = "T", color = "magenta" },
				["?"] = { icon = git_icons.untracked, color = "magenta" },
			},
		},
	},
	keys = function()
		local wk = require("which-key")
		local keys = {
			["<leader>"] = {
				f = {
					name = "FzfLua",
					f = { "<cmd>FzfLua files<cr>", "Find Files" },
					r = { "<cmd>FzfLua live_grep<cr>", "Live Grep" },
					b = { "<cmd>FzfLua buffers<cr>", "Buffers" },
					o = { "<cmd>FzfLua oldfiles<cr>", "Recent Files" },
					h = { "<cmd>FzfLua help_tags<cr>", "Help tags" },
				},
				g = {
					name = "Git",
					c = { "<cmd>FzfLua git_commits<cr>", "Show commits" },
					b = { "<cmd>FzfLua git_branches<cr>", "Show branches" },
				},
				l = {

					name = "LSP",
					p = { "<cmd>FzfLua lsp_document_diagnostics<cr>", "Document dignostics" },
					P = { "<cmd>FzfLua lsp_workspace_diagnostics<cr>", "Document dignostics" },
				},
			},
		}
		wk.register(keys)
	end,
}
