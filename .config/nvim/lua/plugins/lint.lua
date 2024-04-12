return {
	"mfussenegger/nvim-lint",
	dependencies = {
		"williamboman/mason.nvim",
	},
	event = "BufRead",
	config = function()
		local linters_by_ft = {}
    local tool_tbl = require("tools").tools_table
    for ft, tools in pairs(tool_tbl) do
      linters_by_ft[ft] = tools["linters"]
    end
		require("lint").linters_by_ft = linters_by_ft
		local lintGrp = vim.api.nvim_create_augroup("LintAutogroup", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", { command = "lua require('lint').try_lint()", group = lintGrp })
	end,
}
