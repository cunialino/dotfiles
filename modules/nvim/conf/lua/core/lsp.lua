local icons = require("icons")
vim.lsp.enable({
  "lua_ls",
  "nil",
  "nushell",
  "pylsp",
  "ruff",
  "typos_lsp",
  "zk",
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

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.bo[args.buf].formatexpr = nil
    vim.bo[args.buf].omnifunc = nil
    vim.keymap.set("n", "<leader>lK", vim.lsp.buf.hover, { buffer = args.buf, desc = "Docs" })
    vim.keymap.set("n", "<leader>l", "", { buffer = args.buf, desc = "+LSP" })

    vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, { buffer = args.buf, desc = "Go to definition" })
    vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, { buffer = args.buf, desc = "References" })
    vim.keymap.set("n", "<leader>lR", vim.lsp.buf.rename, { buffer = args.buf, desc = "Rename" })
    vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { buffer = args.buf, desc = "Code actions" })
  end
})
