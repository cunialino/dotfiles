-- Lazy blocks `loadplugins`, so a plugin installed outside its control never gets
-- its `plugin/` script sourced; do it here to register the `:Diffview*` commands.
vim.cmd("silent runtime plugin/diffview.lua")

local map = vim.keymap.set

map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Diff working tree" })
map("n", "<leader>gf", "<cmd>DiffviewDiffFiles ", { desc = "Diff Two Files" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File History" })
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", { desc = "Repo History" })
map("n", "<leader>gc", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" })
