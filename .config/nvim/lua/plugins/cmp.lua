return {
	"hrsh7th/nvim-cmp",
	init = function()
		vim.o.completeopt = "menu,menuone,noselect"
	end,
	config = function()
		local has_words_before = function()
			local line, col = unpack(vim.api.nvim_win_get_cursor(0))
			return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
		end

		local feedkey = function(key, mode)
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), mode, true)
		end
		local cmp = require("cmp")
		local lspkind = require("lspkind")

		cmp.setup({
			enabled = function()
				-- disable completion in comments
				local context = require("cmp.config.context")
				-- keep command mode completion enabled when cursor is in a comment
				if vim.api.nvim_get_mode().mode == "c" then
					return true
				else
					return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
				end
			end,
			window = {
				documentation = cmp.config.window.bordered(),
			},
			snippet = {
				expand = function(args)
					vim.fn["vsnip#anonymous"](args.body)
				end,
			},
			formatting = {
				format = lspkind.cmp_format({
					with_text = true,
					maxwidth = 50,
					menu = { buffer = "[  ]", nvim_lsp = "[ 󰅩 ]", vsnip = "[  ]" },
				}),
			},
			mapping = {
				["<C-d>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-o>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.close(),
				["<CR>"] = cmp.mapping.confirm({ select = true }),
				["<Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					elseif vim.fn["vsnip#available"]() == 1 then
						feedkey("<Plug>(vsnip-expand-or-jump)", "")
					elseif has_words_before() then
						cmp.complete()
					else
						fallback() -- The fallback function sends a already mapped key. In this case, it's probably `<Tab>`.
					end
				end, { "i", "s" }),

				["<S-Tab>"] = cmp.mapping(function()
					if cmp.visible() then
						cmp.select_prev_item()
					elseif vim.fn["vsnip#jumpable"](-1) == 1 then
						feedkey("<Plug>(vsnip-jump-prev)", "")
					end
				end, { "i", "s" }),
			},
			sources = {
				{ name = "nvim_lsp_signature_help" },
				{ name = "nvim_lsp" },
				{
					name = "vsnip",
					entry_filter = function()
						local context = require("cmp.config.context")
						return not context.in_treesitter_capture("string") and not context.in_syntax_group("String")
					end,
				},
				{
					name = "buffer",
					entry_filter = function()
						local context = require("cmp.config.context")
						return context.in_treesitter_capture("string") and not context.in_syntax_group("String")
					end,
				},
				{
					name = "path",
					entry_filter = function()
						local context = require("cmp.config.context")
						return context.in_treesitter_capture("string") and not context.in_syntax_group("String")
					end,
				},
			},
		})
	end,
	dependencies = {
		{ "hrsh7th/cmp-nvim-lsp" },
		{ "hrsh7th/cmp-buffer" },
		{ "hrsh7th/cmp-path" },
		{ "hrsh7th/cmp-vsnip" },
		{ "onsails/lspkind-nvim" },
		{
			"hrsh7th/vim-vsnip",
			init = function()
				vim.g.vsnip_snippet_dir = "~/.config/nvim/.vsnip/"
			end,
			dependencies = {
				{ "hrsh7th/vim-vsnip-integ" },
				{ "rafamadriz/friendly-snippets" },
			},
		},
		{
			"ray-x/lsp_signature.nvim",
			config = function()
				require("lsp_signature").setup({})
			end,
		},
	},
}
