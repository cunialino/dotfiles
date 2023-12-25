local custom_fzf = {}

function custom_fzf.load_sessions()
	local fzflua = require("fzf-lua")
	local cmd = "ls " .. vim.fn.stdpath("cache") .. "/session | cut -d '.' -f 1"
	fzflua.fzf_exec(cmd, {
		actions = {
			["default"] = function(selected, opts)
				vim.cmd("SessionLoad " .. selected[1])
			end,
		},
	})
end

function custom_fzf.search_config_files()
	local fzflua = require("fzf-lua")
	fzflua.files({ prompt_title = "Config Files", cwd = vim.fn.stdpath("config") })
end

if custom_fzf.venvs == nil then
	custom_fzf.venvs = {}
end

function custom_fzf.set_env()
	local fzflua = require("fzf-lua")
	local cmd = "fd -H -I -E 'nvim' -E 'pyenv' -E 'pipx' 'activate$' " .. vim.fn.expand("$HOME")
	fzflua.fzf_exec(cmd, {
		fn_transform = function(x)
			local venv_path = string.match(x, "(.*)/bin/activate")
			local prefix = " "
			if custom_fzf.venvs[venv_path] ~= nil then
				prefix = " " .. prefix
			end
			return fzflua.utils.ansi_codes.yellow(prefix) .. venv_path
		end,
		actions = {
			["default"] = function(selected, opts)
				local venv_path = string.match(selected[1], ".*(.*)")
				if venv_path ~= vim.fn.expand("$VIRTUAL_ENV") then
					local old_venv = vim.fn.expand("$VIRTUAL_ENV")
					if old_venv == "$VIRTUAL_ENV" then
						old_venv = ""
					end
					custom_fzf.venvs[venv_path] = {
						old_path = vim.fn.expand("$PATH"),
						old_venv = old_venv,
					}

					vim.fn.setenv("VIRTUAL_ENV", venv_path)
					vim.fn.setenv("PATH", venv_path .. "/bin:" .. vim.fn.expand("$PATH"))
				else
					local old_envs = custom_fzf.venvs[venv_path]
					custom_fzf.venvs[venv_path] = nil
					vim.fn.setenv("VIRTUAL_ENV", old_envs.old_venv)
					vim.fn.setenv("PATH", old_envs.old_path)
				end
			end,
		},
		fzf_opts = {
			["--preview"] = require("fzf-lua").shell.preview_action_cmd(function(items)
				local venv_path = string.match(items[1], ".*(.*)")
				return string.format("%s/bin/pip freeze | bat --style=default --color=always", venv_path)
			end),
		},
	})
end

return custom_fzf
