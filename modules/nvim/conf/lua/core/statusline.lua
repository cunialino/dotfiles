local statusline = {
  ' %t',
  '%r',
  '%m',
  '%=',
  '%{&filetype}',
  ' %2p%%',
  ' %3l:%-2c '
}

local function lsp_clients()
  local curr_buffer = vim.fn.bufnr()
  local clients = vim.lsp.get_clients({ bufnr = curr_buffer })
  local clients_list = {}
  for _, client in pairs(clients) do
    table.insert(clients_list, client.name)
  end
  return " :" .. table.concat(clients_list, ", ")
end

vim.o.statusline = table.concat(statusline, '')
