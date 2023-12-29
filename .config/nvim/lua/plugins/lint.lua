local function convert_to_ft(language)
	if language == "bash" then
		return "sh"
	end
	return language
end
return {
	"mfussenegger/nvim-lint",
	dependencies = {
		"williamboman/mason.nvim",
	},
	event = "BufRead",
	config = function()
		local linters_by_ft = {}
		local mason_linter = require("mason-registry").get_installed_packages()
		for _, v in pairs(mason_linter) do
			for _, cat in pairs(v["spec"]["categories"]) do
				local added = false
				if cat == "Linter" then
					for _, l in pairs(v["spec"]["languages"]) do
						local language = convert_to_ft(string.lower(l))
						linters_by_ft[language] =
							vim.tbl_deep_extend("keep", linters_by_ft[language] or {}, { v["name"] })
						added = true
					end
				end
				if #v["spec"]["languages"] == 0 then
					vim.notify("Linter " .. v["name"] .. " has no ft", vim.log.levels.WARN)
				end
			end
		end
		vim.notify(vim.inspect(linters_by_ft))
		require("lint").linters_by_ft = linters_by_ft
		local lintGrp = vim.api.nvim_create_augroup("LintAutogroup", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", { command = "lua require('lint').try_lint()", group = lintGrp })
	end,
}
