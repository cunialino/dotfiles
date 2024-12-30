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
	opts = function()
		return {
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
				nushell = {
					install_with_mason = false,
				},
				typos_lsp = {
					install_with_mason = true,
				},
				pylsp = {
					install_with_mason = false,
					cmd = { "pylsp" },
					settings = {
						pylsp = {
							plugins = {
								rope_autoimport = { enabled = true },
								pyflakes = { enabled = false },
								pylint = { enabled = false },
								pycodestyle = { enabled = false },
							},
						},
					},
				},
				ruff = {
					install_with_mason = false,
					cmd = { "ruff", "server" },
				},
				lua_ls = {
					install_with_mason = true,
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
				yamlls = {
					install_with_mason = true,
					settings = {
						yaml = {
							schemaStore = {
								-- You must disable built-in schemaStore support if you want to use
								-- this plugin and its advanced options like `ignore`.
								enable = false,
								-- Avoid TypeError: Cannot read properties of undefined (reading 'length')
								url = "",
							},
							schemas = require("schemastore").yaml.schemas({
								replace = {
									["AWS CloudFormation"] = {
										name = "AWS CloudFormation",
										description = "AWS CloudFormation provides a common language for you to describe and provision all the infrastructure resources in your cloud environment",
										fileMatch = {
											"*.cf.json",
											"*.cf.yml",
											"*.cf.yaml",
											"cloudformation.json",
											"cloudformation.yml",
											"cloudformation.yaml",
											"iac/*.yaml",
											"iac/*.yml",
										},
										url = "https://raw.githubusercontent.com/awslabs/goformation/master/schema/cloudformation.schema.json",
									},
								},
							}),
							format = {
								enable = true,
							},
						},
					},
				},
				rust_analyzer = {
					install_with_mason = false,
					settings = {
						["rust-analyzer"] = {
							checkOnSave = {
								command = "clippy",
							},
							cargo = {
								allFeatures = true,
							},
						},
					},
				},
			},
		}
	end,
	config = function(_, opts)
		local lspconfig = require("lspconfig")

		local servers = require("mason-lspconfig").get_installed_servers()
		local server_configs = vim.tbl_keys(opts.servers)

		for i = 1, #server_configs do
			local is_present = false
			for _, server in ipairs(servers) do
				if server == server_configs[i] then
					is_present = true
					break
				end
			end
			if not is_present then
				servers[#servers + 1] = server_configs[i]
			end
		end

		for _, server in pairs(servers) do
			local server_opts = opts.servers[server] or {}
			server_opts.capabilities = vim.tbl_deep_extend(
				"force",
				vim.lsp.protocol.make_client_capabilities(),
				require("blink.cmp").get_lsp_capabilities(),
				server_opts.capabilities or {}
			)
			lspconfig[server].setup(server_opts)
		end
		vim.diagnostic.config(vim.deepcopy(opts.diagnostics))
	end,
	keys = {
		{ "<leader>l", desc = "+LSP" },
		{ "<leader>li", ":LspInfo<cr>", desc = "Connected Language Servers" },
		{ "<leader>lK", "<cmd>lua vim.lsp.buf.hover()<CR>", desc = "Hover" },
		{ "<leader>lw", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", desc = "Add workspace folder" },
		{ "<leader>lW", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", desc = "Remove workspace folder" },
		{
			"<leader>ll",
			"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>",
			desc = "List workspace folder",
		},
		{ "<leader>lt", "<cmd>lua vim.lsp.buf.type_definition()<CR>", desc = "Type definition" },
		{ "<leader>ld", "<cmd>lua vim.lsp.buf.definition()<CR>", desc = "Go to definition" },
		{ "<leader>lD", "<cmd>lua vim.lsp.buf.delaration()<CR>", desc = "Go to declaration" },
		{ "<leader>lr", "<cmd>lua vim.lsp.buf.references()<cr>", desc = "References" },
		{ "<leader>lR", "<cmd>lua vim.lsp.buf.rename()<CR>", desc = "Rename" },
		{ "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<CR>", desc = "Code actions" },
	},
	dependencies = {
		{ "b0o/schemastore.nvim" },
		{ "saghen/blink.cmp" },
		{ "williamboman/mason.nvim" },
	},
}
