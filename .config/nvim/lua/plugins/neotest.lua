local function set_up_adapters(adapters_config)
	local adapters = {}
	for name, config in pairs(adapters_config or {}) do
		if type(name) == "number" then
			if type(config) == "string" then
				config = require(config)
			end
			adapters[#adapters + 1] = config
		elseif config ~= false then
			local adapter = require(name)
			if type(config) == "table" and not vim.tbl_isempty(config) then
				local meta = getmetatable(adapter)
				if adapter.setup then
					adapter.setup(config)
				elseif adapter.adapter then
					adapter.adapter(config)
					adapter = adapter.adapter
				elseif meta and meta.__call then
					adapter(config)
				else
					error("Adapter " .. name .. " does not support setup")
				end
			end
			adapters[#adapters + 1] = adapter
		end
	end
	return adapters
end
return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/neotest-python",
		"rouge8/neotest-rust",
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		adapters = {
			"neotest-python",
			"neotest-rust",
		},
	},
	config = function(_, opts)
		opts.adapters = set_up_adapters(opts.adapters)
		require("neotest").setup(opts)
	end,
	keys = {
		{ "<leader>T", "", desc = "+test" },
		{
			"<leader>Tt",
			function()
				require("neotest").run.run(vim.fn.expand("%"))
			end,
			desc = "Run File",
		},
		{
			"<leader>TT",
			function()
				require("neotest").run.run(vim.uv.cwd())
			end,
			desc = "Run All Test Files",
		},
		{
			"<leader>Tr",
			function()
				require("neotest").run.run()
			end,
			desc = "Run Nearest",
		},
		{
			"<leader>Tl",
			function()
				require("neotest").run.run_last()
			end,
			desc = "Run Last",
		},
		{
			"<leader>Ts",
			function()
				require("neotest").summary.toggle()
			end,
			desc = "Toggle Summary",
		},
		{
			"<leader>To",
			function()
				require("neotest").output.open({ enter = true, auto_close = true })
			end,
			desc = "Show Output",
		},
		{
			"<leader>TO",
			function()
				require("neotest").output_panel.toggle()
			end,
			desc = "Toggle Output Panel",
		},
		{
			"<leader>TS",
			function()
				require("neotest").run.stop()
			end,
			desc = "Stop",
		},
		{
			"<leader>Tw",
			function()
				require("neotest").watch.toggle(vim.fn.expand("%"))
			end,
			desc = "Toggle Watch",
		},
	},
}
