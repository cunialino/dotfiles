local function conv(names, mapping)
	local res = {}
	for _, name in ipairs(names) do
		if mapping[name] ~= nil then
			table.insert(res, mapping[name])
		end
	end
	return res
end
return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		"zapling/mason-conform.nvim",
		"rshkarin/mason-nvim-lint",
	},
	config = function()
		local mason = require("mason")

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

		local lsp_to_mason = require("mason-lspconfig").get_mappings().lspconfig_to_mason
		local lspconfig_names = tools.parse_table("lsp")

		local mason_names = conv(lspconfig_names, lsp_to_mason)

		local conform_to_mason = require("mason-conform.mapping").conform_to_package
		local conform_names = tools.parse_table("formatters")
		local mason_conform_names = conv(conform_names, conform_to_mason)

		local lint_to_mason = require("mason-nvim-lint.mapping").nvimlint_to_package
		local lint_names = tools.parse_table("linters")
		local mason_lint_names = conv(lint_names, lint_to_mason)

		mason_names = table.merge(mason_names, mason_conform_names)
		mason_names = table.merge(mason_names, mason_lint_names)

		mason_names = table.merge(mason_names, tools.parse_table("dap"))
		mason_names = table.merge(mason_names, tools.parse_table("linters"))

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
