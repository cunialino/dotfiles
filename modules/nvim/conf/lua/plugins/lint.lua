return {
	"mfussenegger/nvim-lint",
	event = "BufRead",
	opts = {
		linters_by_ft = require("tools").tool_by_type("linters"),
		events = { "BufWritePost", "BufReadPost", "InsertLeave" },
	},
	config = function(_, opts)
		local lint = require("lint")
		lint.linters_by_ft = opts.linters_by_ft
		local lintGrp = vim.api.nvim_create_augroup("LintAutogroup", { clear = true })
		local M = {}
		function M.lint()
			local names = lint._resolve_linter_by_ft(vim.bo.filetype)
			names = vim.list_extend({}, names)
			if #names == 0 then
				vim.list_extend(names, lint.linters_by_ft["_"] or {})
			end
			vim.list_extend(names, lint.linters_by_ft["*"] or {})
			if #names > 0 then
				lint.try_lint(names)
			end
		end
		vim.api.nvim_create_autocmd(opts.events, { callback = M.lint, group = lintGrp })
	end,
}
