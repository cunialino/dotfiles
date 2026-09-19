-- zellij_send: send code from neovim into another zellij pane.
--
-- Same public API as lua/tmux_send, so the two are interchangeable (see
-- lua/repl_sender, which picks one based on the environment we were started in).
--
-- Targeting works through `M.target`:
--   "bottom"  -> the bottom-most terminal pane that is not this one
--                (the equivalent of tmux's `{bottom}`)
--   "focused" -> whatever pane zellij currently has focused (no --pane-id flag)
--   "2" / "terminal_2" -> that literal pane id
--
-- Sending goes through `zellij action write-chars`, which injects the text as if
-- it had been typed, so a trailing newline makes the receiving shell/REPL run the
-- last line.

local M = {}

M.target = "bottom"
M.strip_all_leading = false

local ZELLIJ = "zellij"

local function remove_empty(lines)
  local filtered = {}
  for _, l in ipairs(lines) do
    if not l:match("^%s*$") then
      table.insert(filtered, l)
    end
  end
  return filtered
end

local function is_line_indented(line)
  local _, num = line:find("^ *")
  local n = num or 0 -- if nil, 0 spaces matched
  return n > 0
end

local function add_blank_lines(lines)
  local out = {}
  for i, line in ipairs(lines) do
    table.insert(out, line)
    local is_indented = is_line_indented(line)
    local needs_new_line = (i == #lines) or (not is_line_indented(lines[i + 1]))
    if is_indented and needs_new_line then
      table.insert(out, "")
    end
  end
  return out
end

local function dedent_lines(lines)
  if not lines or #lines == 0 then
    return lines
  end
  local first = lines[1]
  local _, num = first:find("^ *")
  local n = num or 0 -- if nil, 0 spaces matched

  if n == 0 then
    return lines -- nothing to strip
  end

  local out = {}
  for i, l in ipairs(lines) do
    -- if blank line, we can allow it through as empty
    if l:match("^%s*$") then
      table.insert(out, "")
    else
      -- check if this line starts with at least n spaces
      local sub = l:sub(1, n)
      if sub ~= string.rep(" ", n) then
        error(("Line %d does not have required %d spaces: %q"):format(i, n, l))
      end
      -- strip n spaces
      local stripped = l:sub(n + 1)
      table.insert(out, stripped)
    end
  end
  return out
end

local function prepare_lines(lines)
  local non_empty = remove_empty(lines)
  if #non_empty == 0 then
    vim.notify("zellij_send: nothing to send", vim.log.levels.WARN)
    return
  end

  local ok, dedented = pcall(dedent_lines, non_empty)
  if not ok then
    vim.notify("Indentation error: " .. dedented, vim.log.levels.ERROR)
    return
  end

  lines = add_blank_lines(dedented)

  if M.strip_all_leading then
    for i, l in ipairs(lines) do
      lines[i] = l:gsub("^%s+", "")
    end
  end

  return lines
end

-- All non-plugin (i.e. terminal) panes of the current session, with geometry.
local function terminal_panes()
  local ok, out = pcall(vim.fn.system, { ZELLIJ, "action", "list-panes", "--geometry", "--json" })
  if not ok or type(out) ~= "string" or out == "" then
    return nil
  end
  local decoded_ok, data = pcall(vim.fn.json_decode, out)
  if not decoded_ok or type(data) ~= "table" then
    return nil
  end
  local panes = {}
  for _, p in ipairs(data) do
    if p.is_plugin ~= true then
      table.insert(panes, p)
    end
  end
  return panes
end

local function bottom_pane_id()
  local panes = terminal_panes()
  if not panes or #panes == 0 then
    return nil
  end
  table.sort(panes, function(a, b)
    local a_bottom = (a.pane_y or 0) + (a.pane_rows or 0)
    local b_bottom = (b.pane_y or 0) + (b.pane_rows or 0)
    return a_bottom > b_bottom
  end)
  local own = vim.env.ZELLIJ_PANE_ID
  for _, p in ipairs(panes) do
    if own == nil or tostring(p.id) ~= own then
      return tostring(p.id)
    end
  end
  return nil
end

-- Extra argv that points `zellij action` at the target pane; nil when unresolvable.
local function pane_args()
  if M.target == "focused" then
    return {}
  end
  if M.target ~= "bottom" then
    return { "--pane-id", tostring(M.target) }
  end
  local id = bottom_pane_id()
  if not id then
    return nil
  end
  return { "--pane-id", id }
end

local function send_lines(lines)
  lines = prepare_lines(lines)
  if not lines then
    return
  end

  local args = pane_args()
  if not args then
    vim.notify(
      "zellij_send: no target pane found (M.target = " .. tostring(M.target)
        .. ", own pane = " .. tostring(vim.env.ZELLIJ_PANE_ID) .. ")",
      vim.log.levels.ERROR
    )
    return
  end

  local cmd = { ZELLIJ, "action", "write-chars" }
  vim.list_extend(cmd, args)
  -- trailing newline so the last line is executed, mirroring `tmux paste-buffer`
  table.insert(cmd, table.concat(lines, "\n") .. "\n")

  vim.notify("zellij_send: executing: " .. table.concat(cmd, " "), vim.log.levels.DEBUG)

  local job = vim.fn.jobstart(cmd, {
    on_exit = function(_, code, _)
      if code ~= 0 then
        vim.notify("zellij_send: job exit code " .. code, vim.log.levels.DEBUG)
      end
    end,
  })

  if job <= 0 then
    vim.notify("zellij_send: job failed to start (return " .. tostring(job) .. ")", vim.log.levels.ERROR)
  end
end

local function send_lines_livy(lines)
  local prepped_lines = prepare_lines(lines)

  local tmp_lines = vim.fn.tempname()
  vim.fn.writefile(prepped_lines, tmp_lines)

  local livy_function_call = string.format(
    "_last_livy_response = run_on_livy(session_id, %s)",
    vim.fn.shellescape(tmp_lines)
  )
  local weird_lines = { livy_function_call }
  send_lines(weird_lines)
end

function M.send_line()
  local line = vim.api.nvim_get_current_line()
  send_lines({ line })
end

function M.send_visual()
  local a = vim.fn.getpos("'<")[2]
  local b = vim.fn.getpos("'>")[2]
  local lines = vim.api.nvim_buf_get_lines(0, a - 1, b, false)
  send_lines(lines)
end

function M.send_line_livy()
  local line = vim.api.nvim_get_current_line()
  send_lines_livy({ line })
end

function M.send_visual_livy()
  local a = vim.fn.getpos("'<")[2]
  local b = vim.fn.getpos("'>")[2]
  local lines = vim.api.nvim_buf_get_lines(0, a - 1, b, false)
  send_lines_livy(lines)
end

function M.toggle_strip_all_leading()
  M.strip_all_leading = not M.strip_all_leading
  local status = M.strip_all_leading and "ON" or "OFF"
  vim.notify("zellij_send: strip all leading whitespace " .. status, vim.log.levels.INFO)
end

return M
