local function format_diagnostic(diagnostic)
	if diagnostic.severity == vim.diagnostic.severity.ERROR then
		return string.format("%s %s", require("icons").lsp_signs.Error, diagnostic.message)
	end
	if diagnostic.severity == vim.diagnostic.severity.WARN then
		return string.format("%s %s", require("icons").lsp_signs.Warning, diagnostic.message)
	end
	if diagnostic.severity == vim.diagnostic.severity.INFO then
		return string.format("%s %s", require("icons").lsp_signs.Information, diagnostic.message)
	end
	if diagnostic.severity == vim.diagnostic.severity.HINT then
		return string.format("%s %s", require("icons").lsp_signs.Hint, diagnostic.message)
	end
	return diagnostic.message
end

local function default_on_attach(client, bufnr)
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
			},
		},
	}
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local wk = require("which-key")
	wk.register(keys)
	if string.match(bufname, "conjure") then
		vim.diagnostic.disable(bufnr)
		vim.diagnostic.hide(nil, bufnr)
		vim.diagnostic.reset(nil, bufnr)
		if not vim.lsp.buf_is_attached(bufnr, client.id) then
			vim.lsp.buf_detach_client(bufnr, client.id)
		end
		return
	end
end

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	init = function()
		local signs = {
			Error = require("icons").lsp_signs.Error,
			Warn = require("icons").lsp_signs.Warning,
			Hint = require("icons").lsp_signs.Hint,
			Info = require("icons").lsp_signs.Information,
		}

		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end
	end,
	opts = {
		diagnostics = {
			underline = true,
			update_in_insert = false,
			severity_sort = true,
			virtual_text = {
				source = "if_many",
				prefix = "",
				format = format_diagnostic,
			},
		},
		servers = {
			pylsp = {
				on_attach = default_on_attach,
				settings = {
					pylsp = {
						plugins = {
							pyflakes = { enabled = false },
							pylint = { enabled = false },
							pycodestyle = { enabled = false },
						},
					},
				},
			},
			ruff_lsp = {
				on_attach = function(client, bufnr)
					client.server_capabilities.hoverProvider = false
					default_on_attach(client, bufnr)
				end,
			},
			lua_ls = {
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
			},
			nushell = {
				on_attach = default_on_attach,
			},
		},
	},
	config = function(_, opts)
		require("neodev").setup({})
		local lspconfig = require("lspconfig")
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

		local installed_mslp_servers = require("mason-lspconfig").get_installed_servers()
		local server_configs = vim.tbl_keys(opts.servers)

		local all_servers = vim.tbl_deep_extend("keep", installed_mslp_servers, server_configs)

		for _, server in pairs(all_servers) do
			local server_opts = opts.servers[server] or {}
			server_opts.capabilities = vim.tbl_deep_extend(
				"force",
				vim.lsp.protocol.make_client_capabilities(),
				cmp_nvim_lsp.default_capabilities(),
				server_opts.capabilities or {}
			)
			lspconfig[server].setup(server_opts)
		end
		vim.diagnostic.config(vim.deepcopy(opts.diagnostics))
	end,
	dependencies = {
		{ "b0o/schemastore.nvim" },
		{ "hrsh7th/cmp-nvim-lsp" },
		{ "folke/neodev.nvim" },
	},
}
