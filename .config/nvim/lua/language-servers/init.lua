local lspconfig = require("lspconfig")
local cmp_nvim_lsp = require("cmp_nvim_lsp")

local wk = require("which-key")

local keys = {
	["<leader>"] = {
		l = {
			name = "LSP",
			i = { ":LspInfo<cr>", "Connected Language Servers" },
			K = { "<cmd>lua vim.lsp.buf.hover()<CR>", "Hover" },
			w = { "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", "Add workspace folder" },
			W = { "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", "Remove workspace folder" },
			l = {
				"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>",
				"List workspace folder",
			},
			t = { "<cmd>lua vim.lsp.buf.type_definition()<CR>", "Type definition" },
			d = { "<cmd>lua vim.lsp.buf.definition()<CR>", "Go to definition" },
			D = { "<cmd>lua vim.lsp.buf.delaration()<CR>", "Go to declaration" },
			r = { "<cmd>lua vim.lsp.buf.references()<cr>", "References" },
			R = { "<cmd>lua vim.lsp.buf.rename()<CR>", "Rename" },
			a = { "<cmd>lua vim.lsp.buf.code_action()<CR>", "Code actions" },
			e = { "<cmd>lua vim.diagnostic.open_float()<CR>", "Show line diagnostics" },
			n = { "<cmd>lua vim.diagnostic.goto_next()<CR>", "Go to next diagnostic" },
			N = { "<cmd>lua vim.diagnostic.goto_prev()<CR>", "Go to previous diagnostic" },
			f = { "<cmd>lua vim.lsp.buf.format({ async = true })<CR>", "Format File" },
			I = { "<cmd>Mason<cr>", "Install language server" },
		},
	},
}
local capabilities = cmp_nvim_lsp.default_capabilities()
local default_on_attach = function(client, bufnr)
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	wk.register(keys)
	if string.match(bufname, "conjure") then
		vim.diagnostic.disable(bufnr)
		vim.diagnostic.hide(nil, bufnr)
		vim.diagnostic.reset(nil, bufnr)
		vim.lsp.buf_detach_client(bufnr, client.id)
		return
	end
end

lspconfig["ruff_lsp"].setup({
	capabilities = capabilities,
	on_attach = function(client, bufnr)
		client.server_capabilities.hoverProvider = false
		default_on_attach(client, bufnr)
	end,
})

lspconfig["lua_ls"].setup({
	capabilities = capabilities,
	on_attach = default_on_attach,
	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.stdpath("config") .. "/lua"] = true,
				},
			},
			semantic = {
				enable = false,
			},
		},
	},
})

lspconfig["pylsp"].setup({
	capabilities = capabilities,
	on_attach = default_on_attach,
	settings = {
		pylsp = {
			plugins = {
				pyflakes = { enabled = false },
				pylint = { enabled = false },
			},
		},
	},
})

local signs = {
	Error = icons.lsp_signs.Error,
	Warn = icons.lsp_signs.Warning,
	Hint = icons.lsp_signs.Hint,
	Info = icons.lsp_signs.Information,
}

for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
	underline = true,
	-- virtual_text = { spacing = 5, severity_limit = 'Warning' },
	update_in_insert = true,
	signs = true,
	source = "if_many",
	virtual_text = {
		prefix = "",
		format = function(diagnostic)
			if diagnostic.severity == vim.diagnostic.severity.ERROR then
				return string.format("%s %s", icons.lsp_signs.Error, diagnostic.message)
			end
			if diagnostic.severity == vim.diagnostic.severity.WARN then
				return string.format("%s %s", icons.lsp_signs.Warning, diagnostic.message)
			end
			if diagnostic.severity == vim.diagnostic.severity.INFO then
				return string.format("%s %s", icons.lsp_signs.Information, diagnostic.message)
			end
			if diagnostic.severity == vim.diagnostic.severity.HINT then
				return string.format("%s %s", icons.lsp_signs.Hint, diagnostic.message)
			end
			return diagnostic.message
		end,
	},
})
