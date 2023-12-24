local colors = {
	lightbg = "#4C566A",
	black = "#3B4252",
	red = "#BF616A",
	green = "#A3BE8C",
	yellow = "#EBCB8B",
	blue = "#81A1C1",
	purple = "#B48EAD",
	cyan = "#88C0D0",
	white = "#E5E9F0",
}
return {
	"tamton-aquib/staline.nvim",
	opts = {
		defaults = {
			left_separator = icons.separators.Left,
			right_separator = icons.separators.Right,
			cool_symbol = " ", -- Change this to override defult OS icon.
			full_path = false,
			mod_symbol = " 󰏫 ",
			lsp_client_symbol = " ",
			line_column = "[%l/%L] 󰕱%p%% ", -- `:h stl` to see all flags.
			fg = "#000000", -- Foreground text color.
			bg = "none", -- Default background is transparent.
			inactive_color = "#303030",
			inactive_bgcolor = "none",
			true_colors = false, -- true lsp colors.
			font_active = "none", -- "bold", "italic", "bold,italic", etc
			branch_symbol = " ",
		},
		mode_colors = {
			n = colors.cyan,
			i = colors.blue,
			c = colors.yellow,
			v = colors.purple,
			V = colors.purple,
		},
		mode_icons = {
			n = "󰋜 NORMAL",
			i = "󰏫 INSERT",
			c = " COMMAND",
			v = "󰈈 VISUAL",
			V = "󰈈 VISUAL",
		},
		sections = {
			left = { "-mode", "left_sep_double", " ", "branch" },
			mid = { "lsp_name", "file_name" },
			right = { "right_sep_double", "-line_column" },
		},
		special_table = {
			NvimTree = { "NvimTree", " " },
			packer = { "Packer", "󰇚 " }, -- etc
		},
		lsp_symbols = { Error = "󰅙 ", Info = "󰋼 ", Warn = " ", Hint = "" },
	},
	event = "BufRead",
}
