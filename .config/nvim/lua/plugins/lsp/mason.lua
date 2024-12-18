local function conv(names, mapping)
	local res = {}
	for k, v in pairs(names) do
		local name
		local install_with_mason = nil
		if tonumber(k) then
			name = v
		else
			name = k
			if names[name] ~= nil then
				install_with_mason = names[name].install_with_mason
			end
		end
		if mapping[name] ~= nil and (install_with_mason == nil or install_with_mason) then
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
		local lspconfig_names = require("plugins.lsp.lsp").opts()["servers"]

		local mason_names = conv(lspconfig_names, lsp_to_mason)

		local conform_to_mason = require("mason-conform.mapping").conform_to_package
		local conform_names = tools.parse_table("formatters")
		local mason_conform_names = conv(conform_names, conform_to_mason)

		local lint_to_mason = require("mason-nvim-lint.mapping").nvimlint_to_package
		local lint_names = tools.parse_table("linters")
		local mason_lint_names = conv(lint_names, lint_to_mason)

		vim.list_extend(mason_names, mason_conform_names)
		vim.list_extend(mason_names, mason_lint_names)

		vim.list_extend(mason_names, tools.parse_table("dap"))
		vim.list_extend(mason_names, tools.parse_table("linters"))

		mason_tool_installer.setup({ ensure_installed = mason_names })
	end,
	keys = {
		{ "<leader>lI", "<cmd>Mason<cr>", desc = "Install language server" },
	},
}
