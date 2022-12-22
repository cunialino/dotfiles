local null_ls = require("null-ls")

local formatting = null_ls.builtins.formatting
local ca = null_ls.builtins.code_actions
local diagnostics = null_ls.builtins.diagnostics

null_ls.setup({
  sources = {
    formatting.prettier,
    formatting.black,
    formatting.gofmt,
    formatting.shfmt,
    formatting.stylua,
    formatting.clang_format,
    formatting.cmake_format,
    formatting.isort,
    formatting.codespell.with({ filetypes = { "markdown" } }),
    formatting.phpcsfixer.with({ command = "./tools/php-cs-fixer/vendor/bin/php-cs-fixer" }),
    formatting.shellharden,
    ca.proselint.with({ filtypes = { "tex", "markdown", "text" } }),
    diagnostics.proselint.with({ filtypes = { "tex", "markdown", "text" } }),
  },
  on_attach = function(client)
    if client.resolved_capabilities.document_formatting then
      -- vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()")
      if client.resolved_capabilities.document_highlight then
        vim.api.nvim_exec(
          [[
      augroup document_highlight
        autocmd! * <buffer>
        autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
        autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]]     ,
          false
        )
      end
    end
  end,
})
