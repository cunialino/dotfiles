local M = {}

function prepend_to_path(path)
	local current_path = vim.fn.expand("$PATH")
	vim.fn.setenv("PATH", path .. "/bin/" .. ":" .. current_path)
end

-- return M
---- our picker function: colors

local function list_concat(l1, l2)
	for _, v2 in ipairs(l2) do
		if not vim.tbl_contains(l1, v2) then
			table.insert(l1, v2)
		end
	end
	return l1
end

local function exists(file)
	local ok, err, code = os.rename(file, file)
	if not ok then
		if code == 13 then
			return true
		end
	end
	return ok, err
end

local function get_poetry_vens()
	local res = {}
	if exists("pyproject.toml") and vim.fn.executable("poetry") == 1 then
		local vv = assert(io.popen("poetry env info -p", "r"))
		for c in vv:lines() do
			table.insert(res, c)
		end
		vv:close()
	end
	return res
end

local function get_in_dir_vens(path)
	local res = {}
	if exists(path .. "/") then
		local python_search = "/bin/python$"
		local cmd = "fd --full-path " .. python_search .. " " .. path
		local vv = assert(io.popen(cmd, "r"))
		for c in vv:lines() do
			local parsed_c = c:gsub(python_search, "")
			table.insert(res, parsed_c)
		end
		vv:close()
	end
	return res
end

local venvs = function(opts)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	opts = opts or {}
	local venvs = {}
	local paths_for_venvs = { ".tox", ".venv" }
	for _, p in ipairs(paths_for_venvs) do
		local full_p = vim.fn.getcwd() .. "/" .. p
		list_concat(venvs, get_in_dir_vens(full_p))
	end
	list_concat(venvs, get_poetry_vens())
	pickers
		.new(opts, {
			prompt_title = "Appropriate Virtual Envs",
			finder = finders.new_table({
				results = venvs,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					prepend_to_path(selection[1])
				end)
				return true
			end,
		})
		:find()
end

venvs()
