local icons = require("icons")
vim.lsp.enable({
  "nushell",
  "typos_lsp",
  "zk",
  "pylsp",
  "ruff",
  "lua_ls",
})

vim.diagnostic.config({
  virtual_text = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = true,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = icons.lsp_signs.Error,
      [vim.diagnostic.severity.WARN] = icons.lsp_signs.Warning,
      [vim.diagnostic.severity.INFO] = icons.lsp_signs.Information,
      [vim.diagnostic.severity.HINT] = icons.lsp_signs.Hint,
    },
    numhl = {
      [vim.diagnostic.severity.ERROR] = "ErrorMsg",
      [vim.diagnostic.severity.WARN] = "WarningMsg",
    },
  },
})
