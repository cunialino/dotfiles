return {
	"mfussenegger/nvim-lint",
	dependencies = {
		"williamboman/mason.nvim",
	},
	event = "BufRead",
	config = function()
		local linters_by_ft = require("tools").tool_by_type("linters")
		require("lint").linters_by_ft = linters_by_ft
		local lintGrp = vim.api.nvim_create_augroup("LintAutogroup", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", { command = "lua require('lint').try_lint()", group = lintGrp })
	end,
}
