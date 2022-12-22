require("lint").linters_by_ft = {
	tex = { "proselint" },
	text = { "proselint" },
}

local lintGrp = vim.api.nvim_create_augroup("LintAutogroup", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", { command = "lua require('lint').try_lint()", group = lintGrp })
