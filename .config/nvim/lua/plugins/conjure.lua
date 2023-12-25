return {
	"Olical/conjure",
	ft = { "python", "lua" },
	dependencies = {
		{ "neovim/nvim-lspconfig" },
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
		local wk = require("which-key")
		local keys = {
			["<leader>"] = {
				c = {
					name = "Conjure",
				},
			},
		}
		require("conjure.main").main()
	end,
}
