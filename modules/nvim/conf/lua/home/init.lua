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
