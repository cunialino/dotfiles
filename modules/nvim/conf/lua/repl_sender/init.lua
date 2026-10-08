-- repl_sender: pick the "send code to another pane" backend for the
-- multiplexer we are currently running inside.
--
--   tmux -> lua/tmux_send
--
-- tmux is the only multiplexer we support: outside it there is no backend, and
-- the keymaps below only warn.

local M = {}

local function impl()
  if vim.env.TMUX ~= nil then
    return require("tmux_send")
  end
  return nil
end

local function dispatch(name)
  local mod = impl()
  if not mod then
    vim.notify("repl_sender: not running inside tmux", vim.log.levels.WARN)
    return
  end
  return mod[name]()
end

function M.send_line()
  return dispatch("send_line")
end

function M.send_visual()
  return dispatch("send_visual")
end

function M.send_line_livy()
  return dispatch("send_line_livy")
end

function M.send_visual_livy()
  return dispatch("send_visual_livy")
end

function M.toggle_strip_all_leading()
  return dispatch("toggle_strip_all_leading")
end

-- Which backend would be used right now, for statuslines / debugging.
function M.backend()
  if vim.env.TMUX ~= nil then
    return "tmux"
  end
  return "none"
end

return M
