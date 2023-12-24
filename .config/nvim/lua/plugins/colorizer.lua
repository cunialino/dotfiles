return {
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			local colorizer = require("colorizer")
			colorizer.setup(
				{ "*" },
				{
					RGB = true,
					RRGGBB = true,
					names = true,
					RRGGBBAA = true,
					rgb_fn = true,
					hsl_fn = true,
					css = true,
					css_fn = true,
				}
			)
		end,
		event = "BufRead",
	},
}
