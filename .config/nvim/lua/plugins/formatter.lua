return {
	"mhartington/formatter.nvim",
	config = function()
		require("formatter").setup({
			logging = true,
			log_level = vim.log.levels.WARN,
			filetype = {
				lua = {
					require("formatter.filetypes.lua").stylua,
				},
				latex = {
					require("formatter.filetypes.latex").latexindex,
				},
				python = {
					require("formatter.filetypes.python").ruff,
				},
				sh = {
					require("formatter.filetypes.sh").shfmt,
				},
				json = {
					require("formatter.filetypes.json").jq,
				},
				yaml = {
					require("formatter.filetypes.yaml").prettier,
				},
				["*"] = {
					require("formatter.filetypes.any").remove_trailing_whitespace,
				},
			},
		})
		local formatGrp = vim.api.nvim_create_augroup("FormatAutogroup", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", { command = "FormatWrite", group = formatGrp })
	end,
}
