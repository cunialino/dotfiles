return {
	"hrsh7th/nvim-cmp",
	init = function()
		vim.o.completeopt = "menu,menuone,noselect"
	end,
	event = "InsertEnter",
	opts = function(_, opts)
		vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
		local cmp = require("cmp")
		local defaults = require("cmp.config.default")()
		local lspkind = require("lspkind")
		return {
			completion = {
				completeopt = "menu,menuone,noinsert",
			},
			snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body)
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
				["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
				["<C-f>"] = cmp.mapping.scroll_docs(-4),
				["<C-d>"] = cmp.mapping.scroll_docs(4),
				["<C-o>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
				["<S-CR>"] = cmp.mapping.confirm({
					behavior = cmp.ConfirmBehavior.Replace,
					select = true,
				}), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
				["<C-CR>"] = function(fallback)
					cmp.abort()
					fallback()
				end,
			}),
			sources = cmp.config.sources({
				{
					name = "codeium",
					group_index = 1,
					priority = 100,
				},
				{ name = "nvim_lsp_signature_help" },
				{ name = "nvim_lsp" },
				{ name = "luasnip" },
				{
					name = "buffer",
					entry_filter = function()
						local context = require("cmp.config.context")
						return context.in_treesitter_capture("string") or context.in_syntax_group("String")
					end,
				},
				{
					name = "path",
					entry_filter = function()
						local context = require("cmp.config.context")
						return context.in_treesitter_capture("string") or context.in_syntax_group("String")
					end,
				},
			}),
			formatting = {
				format = lspkind.cmp_format({
					with_text = true,
					maxwidth = 50,
					menu = { buffer = "[  ]", nvim_lsp = "[ 󰅩 ]", vsnip = "[  ]", codeium = "[ 󰧑 ]" },
				}),
				format_cs = require("lspkind").cmp_format({
					mode = "symbol",
					maxwidth = 50,
					ellipsis_char = "...",
					symbol_map = { Codeium = "" },
				}),
			},
			experimental = {
				ghost_text = {
					hl_group = "CmpGhostText",
				},
			},
			sorting = defaults.sorting,
		}
	end,
	---@param opts cmp.ConfigSchema
	config = function(_, opts)
		for _, source in ipairs(opts.sources) do
			source.group_index = source.group_index or 1
		end
		require("cmp").setup(opts)
	end,
	dependencies = {
		{ "hrsh7th/cmp-nvim-lsp" },
		{ "hrsh7th/cmp-buffer" },
		{ "hrsh7th/cmp-path" },
		"saadparwaiz1/cmp_luasnip",
		{ "onsails/lspkind-nvim" },
		{
			"ray-x/lsp_signature.nvim",
			config = function()
				require("lsp_signature").setup({})
			end,
		},
		{
			"Exafunction/codeium.nvim",
			cmd = "Codeium",
			build = ":Codeium Auth",
			opts = {},
		},
	},
}
