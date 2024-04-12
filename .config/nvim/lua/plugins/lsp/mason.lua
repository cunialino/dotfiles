return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		-- import mason
		local mason = require("mason")

		-- import mason-lspconfig

		local mason_tool_installer = require("mason-tool-installer")

    local tools = require("tools")

		-- enable mason and configure icons
		mason.setup({
			ui = {
				icons = {
					package_installed = " ",
					package_pending = " ",
					package_uninstalled = " ",
				},
			},
		})

		mason_tool_installer.setup({
			ensure_installed = tools.parse_table(),			-- auto-install configured servers (with lspconfig)
		})
		local keys = {
			["<leader>"] = {
				l = {
					name = "LSP",
					I = { "<cmd>Mason<cr>", "Install language server" },
				},
			},
		}
		local wk = require("which-key")
		wk.register(keys)
	end,
}
