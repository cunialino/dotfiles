local wk = require("which-key")
local normal_mappings = {
	["<leader>"] = {
		l = {
			name = "LSP",
			i = { ":LspInfo<cr>", "Connected Language Servers" },
			K = { "<cmd>lua vim.lsp.buf.hover()<CR>", "Hover" },
			w = { "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", "Add workspace folder" },
			W = { "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", "Remove workspace folder" },
			l = {
				"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>",
				"List workspace folder",
			},
			t = { "<cmd>lua vim.lsp.buf.type_definition()<CR>", "Type definition" },
			d = { "<cmd>lua vim.lsp.buf.definition()<CR>", "Go to definition" },
			D = { "<cmd>lua vim.lsp.buf.delaration()<CR>", "Go to declaration" },
			r = { ":Trouble lsp_references<CR>", "References" },
			R = { "<cmd>lua vim.lsp.buf.rename()<CR>", "Rename" },
			a = { "<cmd>lua vim.lsp.buf.code_action()<CR>", "Code actions" },
			e = { "<cmd>lua vim.diagnostic.get()<CR>", "Show line diagnostics" },
			n = { "<cmd>lua vim.diagnostic.goto_next()<CR>", "Go to next diagnostic" },
			N = { "<cmd>lua vim.diagnostic.goto_prev()<CR>", "Go to previous diagnostic" },
			I = { "<cmd>LspInstallInfo<cr>", "Install language server" },
			f = { "<cmd>lua vim.lsp.buf.format({ async = true })<CR>", "Format File" },
		},
		x = { ":bdelete<cr>", "Close Buffer" },
		X = { ":bdelete!<cr>", "Force Close Buffer" },
		q = { ":lua UtilityFunctions.saveAndExit()<cr>", "Quit" },
		Q = { ":q!<cr>", "Force Quit" },
		w = { ":w<cr>", "Write" },
		E = { ":e ~/.config/nvim/lua/vapour/user-config/init.lua<cr>", "Edit User Config" },
<<<<<<< Updated upstream
		p = {
			name = "Packer",
			r = { ":PackerClean<cr>", "Remove Unused Plugins" },
			c = { ":PackerCompile profile=true<cr>", "Recompile Plugins" },
			i = { ":PackerInstall<cr>", "Install Plugins" },
			p = { ":PackerProfile<cr>", "Packer Profile" },
			s = { ":lua UtilityFunctions.syncPlugins()<cr>", "Sync Plugins" },
			S = { ":PackerStatus<cr>", "Packer Status" },
			u = { ":PackerUpdate<cr>", "Update Plugins" },
		},
<<<<<<< Updated upstream
=======
		z = {
			name = "Focus",
			z = { ":ZenMode<cr>", "Toggle Zen Mode" },
			t = { ":Twilight<cr>", "Toggle Twilight" },
=======
		l = {
			name = "Lazy",
			r = { ":Lazy clean<cr>", "Remove Unused Plugins" },
			i = { ":Lazy install<cr>", "Install Plugins" },
			p = { ":Lazy profile<cr>", "Lazy Profile" },
			s = { ":Lazy sync<cr>", "Sync Plugins" },
			S = { ":Lazy show<cr>", "Lazy Status" },
			u = { ":Lazy update<cr>", "Update Plugins" },
>>>>>>> Stashed changes
>>>>>>> Stashed changes
		},
		e = { ":NvimTreeToggle<cr>", "File Explorer" },
		g = {
			name = "Git",
			d = { ":DiffviewOpen<cr>", "Open diff view" },
			C = { ":DiffviewClose<cr>", "Close diff view" },
			h = { ":DiffviewFileHistory<cr>", "Open file history" },
			f = { ":DiffviewFocusFiles<cr>", "Diff view focus file" },
			s = { ":Gitsigns stage_hunk<cr>", "Stage hunk" },
			S = { ":Gitsigns stage_buffer<cr>", "Stage buffer" },
			r = { ":Gitsigns reset_hunk<cr>", "Reset hunk" },
			R = { ":Gitsigns reset_buffer<cr>", "Reset buffer" },
			n = { ":Gitsigns next_hunk<cr>", "Next hunk" },
			N = { ":Gitsigns prev_hunk<cr>", "Previous hunk" },
			p = { ":Gitsigns preview_hunk<cr>", "Preview hunk" },
			c = { "<cmd>FzfLua git_commits<cr>", "Show commits" },
			b = { "<cmd>FzfLua git_branches<cr>", "Show branches" },
		},
		f = {
			name = "FzfLua",
			f = { "<cmd>FzfLua files<cr>", "Find Files" },
			r = { "<cmd>FzfLua live_grep<cr>", "Live Grep" },
			b = { "<cmd>FzfLua buffers<cr>", "Buffers" },
			o = { "<cmd>FzfLua oldfiles<cr>", "Recent Files" },
			h = { "<cmd>FzfLua help_tags<cr>", "Help tags" },
		},
		d = {
			name = "Debug",
			b = { "<cmd>lua require'dap'.toggle_breakpoint()<cr>", "Toggle Breakpoint" },
			c = { "<cmd>:lua require'dap'.continue()<cr>", "Continue debug" },
			o = { "<cmd>:lua require'dap'.step_over()<cr>", "Step over" },
			i = { "<cmd>:lua require'dap'.step_into()<cr>", "Step into" },
			t = { "<cmd>:lua require('dapui').toggle()<cr>", "Toggle ui" },
		},
		h = { ":Dashboard<cr>", "Dashboard" },
		t = {
			name = "Trouble",
			x = { "<cmd>TroubleToggle<cr>", "Toggle" },
			q = { "<cmd>TroubleToggle quickfix<cr>", "Quickfix" },
			l = { "<cmd>TroubleToggle loclist<cr>", "Loclist" },
			w = { "<cmd>TroubleToggle workspace_diagnostics<cr>", "Workspace Diagnostics" },
			d = { "<cmd>TroubleToggle document_diagnostics<cr>", "Document Diagnostics" },
		},
		P = { ":lua UtilityFunctions.preview()<cr>", "Quit" },
		u = {
			name = "Utils",
			t = { "<cmd>ToggleTerm<cr>", "Toggle term" },
			f = {
				"<cmd>lua require('toggleterm.terminal').Terminal:new({direction = 'float'}):toggle()<cr>",
				"Toggle float",
			},
			l = {
				"<cmd>lua require('toggleterm.terminal').Terminal:new({cmd='lazygit', direction = 'float'}):toggle()<cr>",
				"Toggle lazygit",
			},
		},
		i = {
			name = "Iron",
			a = { "<cmd>IronAttach<cr>", "Iron attach" },
			f = { "<cmd>IronFocus<cr>", "Iron focus" },
			h = { "<cmd>IronHide<cr>", "Iron hide" },
			s = { "<cmd>IronRepl<cr>", "Iron REPL" },
			r = { "<cmd>IronRestart<cr>", "Iron Restart" },
		},
		o = { ":only<cr>", "Only" },
		["/"] = { ":CommentToggle<cr>", "Toggle Comment" },
	},
	f = {
		"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = false })<cr>",
		"Char forward",
	},
	F = {
		"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = false })<cr>",
		"Char backward",
	},
	S = {
		"<cmd>lua require'hop'.hint_patterns()<cr>",
		"Pattern search",
	},
}

wk.register(normal_mappings)
