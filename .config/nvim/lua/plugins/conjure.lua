vim.g["conjure#mapping#prefix"] = vim.g.mapleader .. "c"
vim.g["conjure#mapping#doc_word"] = false
vim.g["conjure#mapping#def_word"] = false

local function set_keys()
	local filetype = vim.bo.filetype
	local wk = require("which-key")
	wk.register({
		["<leader>"] = {
			c = {
				name = "Conjure",
				e = "Eval",
				l = "Log",
				r = "FT",
			},
		},
	})
end

return {
	"Olical/conjure",
	lazy = true,
	priority = 0,
	init = function()
		local wk = require("which-key")
		wk.register({
			["<leader>"] = {
				c = { ":Lazy load conjure<cr>", "Load conjure" },
			},
		})
	end,
	dependencies = {
		{
			"PaterJason/cmp-conjure",
			config = function()
				local cmp = require("cmp")
				local config = cmp.get_config()
				table.insert(config.sources, {
					name = "buffer",
					option = {
						sources = {
							{ name = "conjure" },
						},
					},
				})
				cmp.setup(config)
			end,
		},
	},
	config = function(_, opts)
		require("conjure.main").main()
		require("conjure.mapping")["on-filetype"]()
		set_keys()
	end,
}
