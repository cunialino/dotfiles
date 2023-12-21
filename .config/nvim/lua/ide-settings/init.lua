icons = {
	lsp_signs = { Error = "", Warning = "", Hint = "󰌶", Information = "" },
	separators = { Left = "", Right = "" },
}
ide_settings = {
	staline_theme = "normal",
	indent = { rainbow = false },
	language_servers = {
		lua_ls = {
			config = function(opts)
				opts = vim.tbl_deep_extend("force", {
					on_init = function(client)
						local path = client.workspace_folders[1].name
						if
							not vim.loop.fs_stat(path .. "/.luarc.json")
							and not vim.loop.fs_stat(path .. "/.luarc.jsonc")
						then
							client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
								Lua = {
									runtime = {
										version = "LuaJIT",
									},
									workspace = {
										checkThirdParty = false,
										library = vim.api.nvim_get_runtime_file("", true),
									},
								},
							})

							client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
						end
						return true
					end,
				}, opts)
				return opts
			end,
		},
		jsonls = {
			config = function(opts)
				opts = vim.tbl_deep_extend("force", {
					settings = { json = { schemas = require("schemastore").json.schemas() } },
				}, opts)
				return opts
			end,
		},
		pylsp = {
			config = function(opts)
				opts = vim.tbl_deep_extend("force", {
					settings = {},
				}, opts)
				return opts
			end,
		},
		ruff_lsp = {
			config = function(opts)
				opts = vim.tbl_deep_extend("force", {
					on_attach = function(client, bufnr)
						client.server_capabilities.hoverProvider = false
					end,
					settings = {},
				}, opts)
				return opts
			end,
		},
	},
}
