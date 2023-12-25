return {
	"Olical/conjure",
	ft = { "lua", "python" },
	priority = 0,
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
	end,
}
