vim.lsp.enable({
  "lua_ls",
  "nil",
  "nushell",
  "pylsp",
  "ruff",
  "rust-analyzer",
  "terraformls",
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
    numhl = {
      [vim.diagnostic.severity.ERROR] = "ErrorMsg",
    },
  },
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.bo[args.buf].formatexpr = nil
    vim.keymap.set("n", "<leader>lK", vim.lsp.buf.hover, { buffer = args.buf, desc = "Docs" })
    vim.keymap.set("n", "<leader>l", "", { buffer = args.buf, desc = "+LSP" })

    vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, { buffer = args.buf, desc = "Go to definition" })
    vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, { buffer = args.buf, desc = "References" })
    vim.keymap.set("n", "<leader>lR", vim.lsp.buf.rename, { buffer = args.buf, desc = "Rename" })
    vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { buffer = args.buf, desc = "Code actions" })
    vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { buffer = args.buf, desc = "Code actions" })

    vim.lsp.completion.enable(true, args.data.client_id, args.buf, {
      autotrigger = true,
      convert = function(item)
        return { abbr = item.label:gsub("%b()", "") }
      end,
    })
  end
})
