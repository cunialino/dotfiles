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

		local conversion_table = require("mason-lspconfig").get_mappings().lspconfig_to_mason
		local lspconfig_names = tools.parse_table()
		local mason_names = {}
		for _, lsp_name in ipairs(lspconfig_names) do
      if conversion_table[lsp_name] ~= nil then
        vim.notify(lsp_name)
        table.insert(mason, conversion_table[lsp_name])
      end
		end

		mason_tool_installer.setup({
			ensure_installed = mason_names, -- auto-install configured servers (with lspconfig)
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
