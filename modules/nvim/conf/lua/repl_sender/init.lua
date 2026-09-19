-- repl_sender: pick the right "send code to another pane" backend for the
-- multiplexer we are currently running inside.
--
--   tmux   -> lua/tmux_send
--   zellij -> lua/zellij_send
--
-- tmux wins when both are set, so a `tmux` session nested inside a zellij pane
-- still talks to the pane next to it inside tmux.

local M = {}

local function impl()
  if vim.env.TMUX ~= nil then
    return require("tmux_send")
  end
  if vim.env.ZELLIJ ~= nil or vim.env.ZELLIJ_SESSION_NAME ~= nil then
    return require("zellij_send")
  end
  return nil
end

local function dispatch(name)
  local mod = impl()
  if not mod then
    vim.notify("repl_sender: not running inside tmux or zellij", vim.log.levels.WARN)
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
  if vim.env.ZELLIJ ~= nil or vim.env.ZELLIJ_SESSION_NAME ~= nil then
    return "zellij"
  end
  return "none"
end

return M
