---@type vim.lsp.Config
return {
	cmd = { "pylsp" },
	filetypes = { "python" },
	settings = {
		pylsp = {
			plugins = {
				rope_autoimport = { enabled = true },
				pyflakes = { enabled = false },
				pylint = { enabled = false },
				pycodestyle = { enabled = false },
			},
		},
	},
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"requirements.txt",
		"Pipfile",
		".git",
	},
}
