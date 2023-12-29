local function lsp_clients()
	local clients = vim.lsp.get_active_clients()
	local clients_list = {}
	for _, client in pairs(clients) do
		table.insert(clients_list, client.name)
	end
	return " :" .. table.concat(clients_list, ", ")
end
return {
	"nvim-lualine/lualine.nvim",
	event = "BufWinEnter",
	init = function()
		vim.g.lualine_laststatus = vim.o.laststatus
		if vim.fn.argc(-1) > 0 then
			-- set an empty statusline till lualine loads
			vim.o.statusline = " "
		else
			-- hide the statusline on the starter page
			vim.o.laststatus = 0
		end
	end,
	opts = function()
		-- PERF: we don't need this lualine require madness 🤷
		local lualine_require = require("lualine_require")
		lualine_require.require = require

		local icons = require("icons")

		vim.o.laststatus = vim.g.lualine_laststatus

		return {
			options = {
				theme = "auto",
				globalstatus = true,
				disabled_filetypes = { statusline = { "dashboard", "alpha", "starter" } },
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch" },

				lualine_c = {
					{ "filetype", icon_only = true, padding = { left = 1, right = 1 } },
					{
						lsp_clients,
					},
					{
						"diagnostics",
						symbols = {
							error = icons.lsp_signs.Error,
							warn = icons.lsp_signs.Warn,
							info = icons.lsp_signs.Info,
							hint = icons.lsp_signs.Hint,
						},
					},
				},
				lualine_x = {
					{
						function()
							return "  " .. require("dap").status()
						end,
						cond = function()
							return package.loaded["dap"] and require("dap").status() ~= ""
						end,
					},
					{
						require("lazy.status").updates,
						cond = require("lazy.status").has_updates,
					},
					{
						"diff",
						symbols = {
							added = icons.git.staged,
							modified = icons.git.unstaged,
							removed = icons.git.deleted,
						},
						source = function()
							local gitsigns = vim.b.gitsigns_status_dict
							if gitsigns then
								return {
									added = gitsigns.added,
									modified = gitsigns.changed,
									removed = gitsigns.removed,
								}
							end
						end,
					},
				},
				lualine_y = {
					{ "progress", separator = " ", padding = { left = 1, right = 0 } },
					{ "location", padding = { left = 0, right = 1 } },
				},
				lualine_z = {
					function()
						return " " .. os.date("%R")
					end,
				},
			},
			extensions = { "lazy" },
		}
	end,
}
