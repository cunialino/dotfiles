local function smart_move(direction, tmux_cmd)
  local curwin = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. direction)
  if curwin == vim.api.nvim_get_current_win() then
    vim.fn.system('tmux select-pane ' .. tmux_cmd)
  end
end

vim.keymap.set('n', '<C-h>', function() smart_move('h', '-L') end, { silent = true })
vim.keymap.set('n', '<C-j>', function() smart_move('j', '-D') end, { silent = true })
vim.keymap.set('n', '<C-k>', function() smart_move('k', '-U') end, { silent = true })
vim.keymap.set('n', '<C-l>', function() smart_move('l', '-R') end, { silent = true })

vim.api.nvim_set_keymap("n", "<leader>-", "", {
  callback = function()
    local dir = vim.fn.expand("%:h")
    vim.fn.system({ "tmux", "new-window", "-c", dir, "yazi; tmux select-window -t !" })
  end,
  desc = "Run yazi in current buffer dir"
})
