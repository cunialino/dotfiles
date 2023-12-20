local fzflua = require("fzf-lua")

local custom_fzf = {}

function custom_fzf.load_sessions()
	cmd = "ls " .. vim.fn.stdpath("cache") .. "/session | cut -d '.' -f 1"
	fzflua.fzf_exec(cmd, {
		actions = {
			["default"] = function(selected, opts)
				vim.cmd("SessionLoad " .. selected[1])
			end,
		},
	})
end

function custom_fzf.search_config_files()
	fzflua.files({ prompt_title = "Config Files", cwd = vim.fn.stdpath("config") })
end

return custom_fzf
