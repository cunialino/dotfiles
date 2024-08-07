return {
	"hrsh7th/nvim-cmp",
	init = function()
		vim.o.completeopt = "menu,menuone,noselect"
	end,
	event = "InsertEnter",
	opts = function(_, _)
		vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
		local cmp = require("cmp")
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
				{ name = "nvim_lsp_signature_help" },
				{ name = "nvim_lsp" },
				{ name = "luasnip" },

				{ name = "nvim_lsp_signature_help" },
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
					menu = { buffer = "[  ]", nvim_lsp = "[ 󰅩 ]", vsnip = "[  ]" },
				}),
				format_cs = require("lspkind").cmp_format({
					mode = "symbol",
					maxwidth = 50,
					ellipsis_char = "...",
				}),
			},
			experimental = {
				ghost_text = {
					hl_group = "CmpGhostText",
				},
			},
			sorting = {
				comparators = {
					cmp.config.compare.offset,
					cmp.config.compare.exact,
					cmp.config.compare.score,
					require("cmp-under-comparator").under,
					cmp.config.compare.kind,
					cmp.config.compare.sort_text,
					cmp.config.compare.length,
					cmp.config.compare.order,
				},
			},
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
		{ "hrsh7th/cmp-nvim-lsp-signature-help" },
		{ "lukas-reineke/cmp-under-comparator" },
	},
}
