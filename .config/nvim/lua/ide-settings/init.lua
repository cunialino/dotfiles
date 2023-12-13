icons = {
	lsp_signs = { Error = "", Warning = "", Hint = "󰌶", Information = "" },
	separators = { Left = "", Right = "" },
}
ide_settings = {
	staline_theme = "normal",
	indent = { rainbow = false },
	language_servers = {
		sumneko_lua = {
			config = function(opts)
				opts = vim.tbl_deep_extend("force", {
					settings = {
						Lua = {
							runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
							diagnostics = { globals = { "vim" } },
							workspace = {
								library = vim.api.nvim_get_runtime_file("", true),
								checkThirdParty = false,
								preloadFileSize = 10000,
							},
							telemetry = { enable = false },
						},
					},
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

UtilityFunctions = {
	saveAndExit = function()
		--vim.cmd("SessionSave")
		vim.cmd("wq")
	end,
	syncPlugins = function()
		vim.cmd("PackerSnapshot backup")
		vim.cmd("PackerSync")
	end,
	preview = function()
		local filetype = vim.bo.filetype
		if filetype == "tex" then
			vim.cmd("LatexPreviewToggle")
		elseif filetype == "markdown" then
			vim.cmd("MarkdownPreviewToggle")
		end
	end,
}
