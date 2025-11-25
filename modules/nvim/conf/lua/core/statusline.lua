local cmp = {}

function _G._statusline_component(name)
  return cmp[name]()
end

function cmp.lsp_clients()
  local curr_buffer = vim.fn.bufnr()
  local clients = vim.lsp.get_clients({ bufnr = curr_buffer })
  local clients_list = {}
  for _, client in pairs(clients) do
    table.insert(clients_list, client.name)
  end
  return "LSPs: " .. table.concat(clients_list, ", ")
end

local statusline = {
  " %t ",
  "%{%v:lua._statusline_component('lsp_clients')%}",
  "%r",
  "%m",
  "%=",
  "%{&filetype}",
  "%3l:%-2c"
}


vim.o.statusline = table.concat(statusline, '')
