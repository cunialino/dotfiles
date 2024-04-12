return
{
  'stevearc/aerial.nvim',
  config = true,
  dependencies = {
     "nvim-treesitter/nvim-treesitter",
     "nvim-tree/nvim-web-devicons"
  },
  keys = {
    {"{", "<cmd>AerialPrev<CR>", desc = "Aerial Prev"},
    {"}", "<cmd>AerialNext<CR>", desc = "Aerial Prev"},
    {"a", "<cmd>AerialToggle!<CR>", desc = "Toggle Aerial"}
  }
}
