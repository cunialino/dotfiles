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
vim.o.hlsearch = false
vim.o.ignorecase = true
vim.o.scrolloff = 3
vim.o.sidescrolloff = 5
vim.o.mouse = "a"

vim.o.colorcolumn = "80"

vim.wo.wrap = false
vim.wo.number = true
vim.wo.cursorline = true
vim.wo.signcolumn = "yes"
vim.wo.relativenumber = true

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
local paste_cmd = "wl-paste"
if is_wsl then
  paste_cmd = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe "
      .. '-c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))'
end
vim.g.clipboard = {
  name = "WslClipboard",
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ["+"] = paste_cmd,
    ["*"] = paste_cmd,
  },
  cache_enabled = 0,
}

vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.opt.completeopt = { "menuone", "noselect", "popup" }
require('vim._core.ui2').enable()


local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false
vim.g.termfeatures = termfeatures

vim.api.nvim_set_keymap("n", "<leader>t", "", { desc = "+Tmux Send", noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>t", "", { desc = "+Tmux Send", noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>tt", ":lua require('tmux_send').send_line()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>tt", ":lua require('tmux_send').send_visual()<CR>",
  { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "<leader>tl", ":lua require('tmux_send').send_line_livy()<CR>",
  { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>tl", ":lua require('tmux_send').send_visual_livy()<CR>",
  { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "<leader>ts", ":lua require('tmux_send').toggle_strip_all_leading()<CR>",
  { noremap = true, silent = true })

vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf)
  end
})
local function my_custom_dashboard()
  if vim.fn.argc() > 0 or vim.fn.line2byte(vim.fn.line("$")) ~= -1 then
    return
  end

  local ascii = {
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡤⠴⠒⠒⠒⠶⢤⣄⡀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⠀⠀⠀⠀⠀⠀⠈⠙⢦⡀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⡼⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢳⡀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⢸⠁⠀⠀⣠⠖⠛⠛⠲⢤⠀⠀⠀⣰⠚⠛⢷⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⣿⠀⠀⣸⠃⠀⠀⢀⣀⠈⢧⣠⣤⣯⢠⣤⠘⣆⠀⠀⠀",
    "⠀⠀⠀⠀⠀⣿⠀⠀⡇⠀⠀⠀⠻⠟⠠⣏⣀⣀⣨⡇⠉⢀⣿⠀⠀⠀",
    "⠀⠀⠀⠀⢀⡟⠀⠀⠹⡄⠀⠀⠀⠀⠀⠉⠑⠚⠉⠀⣠⡞⢿⠀⠀⠀",
    "⠀⠀⠀⢀⡼⠁⠀⠀⠀⠙⠳⢤⡄⠀⠀⠀⠀⠀⠀⠀⠁⠙⢦⠳⣄⠀",
    "⠀⠀⢀⡾⠁⠀⠀⠀⠀⠀⠤⣏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠃⠙⡆",
    "⠀⠀⣼⠁⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⠀⢠⡏⠀⠀⡇",
    "⠀⠀⣏⠀⠀⠀⠀⠲⣄⡀⠀⠀⠀⠸⡄⠀⠀⠀⠀⠀⠀⢸⠀⢀⡼⠁",
    "⢀⡴⢿⠀⠀⠀⠀⠀⢸⠟⢦⡀⠀⢀⡇⠀⠀⠀⠀⠀⠀⠘⠗⣿⠁⠀",
    "⠸⣦⡘⣦⠀⠀⠀⠀⣸⣄⠀⡉⠓⠚⠀⠀⠀⠀⠀⠀⠀⠀⡴⢹⣦⡀",
    "⠀⠀⠉⠛⠳⢤⣴⠾⠁⠈⠟⠉⣇⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⣠⠞⠁",
    "⠀⠀⠀⠀⠀⠀⠙⢧⣀⠀⠀⣠⠏⠀⠀⢀⣀⣠⠴⠛⠓⠚⠋⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠋⠉⠉⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  }

  local citation = {
    " ",
    "“The prize is in the pleasure of finding the thing out, ",
    "the kick in the discovery, the observation that other people use it.",
    "Those are the real things, the honors are unreal to me.”",
    "― Richard Feynman",
  }

  local buf = vim.api.nvim_get_current_buf()
  vim.opt_local.colorcolumn = ""
  vim.opt_local.bufhidden = "wipe"
  vim.opt_local.buftype = "nofile"
  vim.opt_local.matchpairs = ""
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.cursorline = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.foldcolumn = "0"

  local old_laststatus = vim.opt.laststatus
  local old_showtabline = vim.opt.showtabline
  vim.opt.laststatus = 0
  vim.opt.showtabline = 0

  local screen_height = vim.o.lines
  local screen_width = vim.o.columns

  local ascii_height = #ascii
  local citation_height = #citation

  local top_padding_count = math.floor((screen_height / 2) - (ascii_height / 2)) - 2
  local footer_padding_count = screen_height - top_padding_count - ascii_height - citation_height - 3

  local all_lines = {}

  for _ = 1, top_padding_count do table.insert(all_lines, "") end

  for _, line in ipairs(ascii) do
    local shift = math.floor((screen_width - vim.fn.strdisplaywidth(line)) / 2)
    table.insert(all_lines, string.rep(" ", shift) .. line)
  end

  for _ = 1, footer_padding_count do table.insert(all_lines, "") end

  for _, line in ipairs(citation) do
    local shift = math.floor((screen_width - vim.fn.strdisplaywidth(line)) / 2)
    table.insert(all_lines, string.rep(" ", shift) .. line)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  vim.opt_local.modifiable = false

  vim.cmd("highlight DashboardBlue guifg=#89b4fa")
  vim.cmd("highlight DashboardYellow guifg=#f9e2af")

  local ns_id = vim.api.nvim_create_namespace("dashboard_highlights")

  for i = 0, ascii_height - 1 do
    local line_idx = top_padding_count + i
    vim.hl.range(buf, ns_id, "DashboardBlue", { line_idx, 0 }, { line_idx, -1 })
  end

  for i = 0, citation_height - 1 do
    local line_idx = #all_lines - citation_height + i
    vim.hl.range(buf, ns_id, "DashboardYellow", { line_idx, 0 }, { line_idx, -1 })
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      vim.opt.laststatus = old_laststatus
      vim.opt.showtabline = old_showtabline
    end,
  })
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = my_custom_dashboard
})
