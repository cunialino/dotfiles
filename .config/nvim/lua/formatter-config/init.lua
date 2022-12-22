local util = require("formatter.util")
local api = vim.api

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
			require("formatter.filetypes.python").black,
			require("formatter.filetypes.python").isort,
		},
		sh = {
			require("formatter.filetypes.sh").shfmt,
		},
		json = {
			require("formatter.filetypes.json").jq,
		},
		yaml = {
			require("formatter.filetypes.yaml").yamlfmt,
		},
		["*"] = {
			require("formatter.filetypes.any").remove_trailing_whitespace,
		},
	},
})
local formatGrp = api.nvim_create_augroup("FormatAutogroup", { clear = true })
api.nvim_create_autocmd("BufWritePost", { command = "FormatWrite", group = formatGrp })
