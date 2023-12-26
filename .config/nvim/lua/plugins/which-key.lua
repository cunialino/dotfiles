vim.api.nvim_set_keymap("n", "<M-j>", ":resize -2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<M-k>", ":resize +2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<M-h>", ":vertical resize -2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<M-l>", ":vertical resize +2<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "<C-h>", "<C-w>h", { noremap = true, silent = false })
vim.api.nvim_set_keymap("n", "<C-j>", "<C-w>j", { noremap = true, silent = false })
vim.api.nvim_set_keymap("n", "<C-k>", "<C-w>k", { noremap = true, silent = false })
vim.api.nvim_set_keymap("n", "<C-l>", "<C-w>l", { noremap = true, silent = false })

vim.api.nvim_set_keymap("n", "<Tab>", ":bnext<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<S-Tab>", ":bprevious<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("v", "<", "<gv", { noremap = true, silent = false })
vim.api.nvim_set_keymap("v", ">", ">gv", { noremap = true, silent = false })

vim.api.nvim_set_keymap("x", "K", ":move '<-2<CR>gv-gv", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "J", ":move '>+1<CR>gv-gv", { noremap = true, silent = true })

vim.api.nvim_set_keymap("v", "<leader>/", ":CommentToggle<cr>", { noremap = true, silent = true })

vim.cmd('inoremap <expr> <c-j> ("\\<C-n>")')
vim.cmd('inoremap <expr> <c-k> ("\\<C-p>")')
vim.cmd("vnoremap // y/\\V<C-R>=escape(@\",'/')<CR><CR>")
return {
	"folke/which-key.nvim",
	event = "VimEnter",
	config = function()
		local wk = require("which-key")

		local keys = {
			["<leader>"] = {
				x = { ":bdelete<cr>", "Close Buffer" },
				X = { ":bdelete!<cr>", "Force Close Buffer" },
				q = { ":wq<cr>", "Save and Quit" },
				Q = { ":q!<cr>", "Force Quit" },
				w = { ":w<cr>", "Write" },
				L = { ":Lazy<cr>", "Lazy" },
				e = { ":NvimTreeToggle<cr>", "File Explorer" },
				E = { ":lua require('custom-fzf').set_env()<cr>", "Set python venv" },
				h = { ":Dashboard<cr>", "Dashboard" },
				o = { ":only<cr>", "Only" },
			},
		}
		wk.register(keys)
	end,
}
