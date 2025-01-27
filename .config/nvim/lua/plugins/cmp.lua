return {
	"saghen/blink.cmp",
	version = "*",
	dependencies = { { "rafamadriz/friendly-snippets" }, { "L3MON4D3/LuaSnip", version = "v2.*" } },
	opts = {
		keymap = {
			-- set to 'none' to disable the 'default' preset
			preset = "none",
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide" },
			["<CR>"] = { "select_and_accept", "fallback" },
			["<C-y>"] = { "select_and_accept" },
			["<C-p>"] = { "select_prev", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },

			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<Tab>"] = { "snippet_forward", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
		},

		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},
		completion = {
			documentation = { auto_show = true, auto_show_delay_ms = 500 },

			ghost_text = { enabled = true },
		},

		signature = { enabled = true },
		snippets = { preset = "luasnip" },
		sources = {
			default = { "lazydev", "snippets", "lsp", "path", "snippets", "buffer" },
			providers = {
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					-- make lazydev completions top priority (see `:h blink.cmp`)
					score_offset = 100,
				},
			},
		},
	},
	opts_extend = { "sources.default" },
}
