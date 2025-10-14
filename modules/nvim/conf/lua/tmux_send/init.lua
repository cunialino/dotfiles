local M = {}

M.target = "{bottom}"

local cmd_template = "bash -c 'tmux load-buffer %s && tmux paste-buffer -t %s'"

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
    local needs_new_line = (i == #lines) or ( not is_line_indented(lines[i + 1]))
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
    vim.notify("tmux_send: nothing to send", vim.log.levels.WARN)
    return
  end

  local ok, dedented = pcall(dedent_lines, non_empty)
  if not ok then
    vim.notify("Indentation error: " .. dedented, vim.log.levels.ERROR)
    return
  end

  lines = add_blank_lines(dedented)

  return lines
end

local function send_lines(lines)
  lines = prepare_lines(lines)
  local tmp = vim.fn.tempname()
  vim.fn.writefile(lines, tmp)

  local cmd = string.format(
    cmd_template,
    vim.fn.shellescape(tmp),
    M.target,
    M.target
  )

  vim.notify("tmux_send: executing: " .. cmd, vim.log.levels.DEBUG)

  local job = vim.fn.jobstart(cmd, {
    on_exit = function(_, code, _)
      if code ~= 0 then
        vim.notify("tmux_send: job exit code " .. code, vim.log.levels.DEBUG)
      end
      -- pcall(os.remove, tmp)
    end,
  })

  if job <= 0 then
    vim.notify("tmux_send: job failed to start (return " .. tostring(job) .. ")", vim.log.levels.ERROR)
  end
end

local function send_lines_livy(lines)
  local prepped_lines = prepare_lines(lines)

  local tmp_lines = vim.fn.tempname()
  vim.fn.writefile(prepped_lines, tmp_lines)

  local livy_function_call = string.format("_last_livy_response = run_on_livy(session_id, %s)",
    vim.fn.shellescape(tmp_lines))
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

return M
