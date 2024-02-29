local tabwidth = 2
vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.cmd("filetype plugin indent on")
vim.o.shortmess = vim.o.shortmess .. "c"
vim.o.hidden = true
vim.o.whichwrap = "b,s,<,>,[,],h,l"
vim.o.pumheight = 10
vim.o.fileencoding = "utf-8"
vim.o.cmdheight = 2
vim.o.splitbelow = true
vim.o.termguicolors = true
vim.o.splitright = true
vim.opt.termguicolors = true
vim.o.conceallevel = 0
vim.o.showtabline = 2
vim.o.showmode = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.updatetime = 300
vim.o.timeoutlen = 100
vim.o.clipboard = "unnamedplus"
vim.o.hlsearch = false
vim.o.ignorecase = true
vim.o.scrolloff = 3
vim.o.sidescrolloff = 5
vim.o.mouse = "a"

vim.wo.wrap = false
vim.wo.number = true
vim.wo.cursorline = true
vim.wo.signcolumn = "yes"

vim.o.tabstop = tabwidth
vim.bo.tabstop = tabwidth
vim.o.softtabstop = tabwidth
vim.bo.softtabstop = tabwidth
vim.o.shiftwidth = tabwidth
vim.bo.shiftwidth = tabwidth
vim.o.autoindent = true
vim.bo.autoindent = true
vim.o.expandtab = true
vim.bo.expandtab = true

-- Disable various builtin plugins in Vim that bog down speed
vim.g.loaded_matchparen = 1
vim.g.loaded_matchit = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_shada_plugin = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_tutor_mode_plugin = 1
vim.g.loaded_remote_plugins = 1

vim.g.jupytext_fmt = "py:percent"

local is_wsl = string.match(string.lower(vim.fn.system({ "uname", "-r" })), "wsl2") ~= nil
if is_wsl then
	local clip_cmd =
		"/mnt/c/Windows/WinSxS/amd64_microsoft-windows-clip_31bf3856ad364e35_10.0.19041.1_none_5dccefa0bb5ef60b/clip.exe"

	local powershell_cmd = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe "
		.. '-c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))'

	vim.g.clipboard = {
		name = "WslClipboard",
		copy = {
			["+"] = clip_cmd,
			["*"] = clip_cmd,
		},
		paste = {
			["+"] = powershell_cmd,
			["*"] = powershell_cmd,
		},
		cache_enabled = 0,
	}
end
