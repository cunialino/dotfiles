return {
  "ibhagwan/fzf-lua",
  opts = function()
    local M = {}

    M.winopts = {
      height  = 0.8,
      width   = 0.8,
      preview = {
        default = "bat",
        wrap    = "nowrap",
      },
    }

    M.fzf_opts = {
      ["--prompt"] = " ",
      ["--info"]   = "inline",
      ["--height"] = "100%",
    }

    M.grep = {
      rg_opts = "--hidden --no-heading --with-filename --line-number --column --smart-case --color=never",
    }

    M.keymap = {
      builtin = {
        i = {
          ["<C-Down>"] = "preview-page-down",
          ["<C-Up>"]   = "preview-page-up",
          ["<C-f>"]    = "preview-page-down",
          ["<C-u>"]    = "preview-page-up",
        },
      },
    }

    return M
  end,

  config = function(_, opts)
    local fzf = require("fzf-lua")
    fzf.setup(opts)
    fzf.register_ui_select()
  end,

  keys = {
    { "<leader>f", "", desc = "+FZF" },
    { "<leader>ff", function() require("fzf-lua").files() end, desc = "Files" },
    { "<leader>fF", function() require("fzf-lua").files() end, desc = "Files" },
    { "<leader>fg", function() require("fzf-lua").git_files() end, desc = "Git Files" },
    { "<leader>fb", function() require("fzf-lua").buffers() end, desc = "Buffers" },
    { "<leader>fs", function() require("fzf-lua").live_grep() end, desc = "Search" },
    { "<leader>fR", function() require("fzf-lua").resume() end, desc = "Resume" },
    { "<leader>ft", function() require("fzf-lua").lsp_document_symbols() end, desc = "Document Symbols" },
    { "<leader>fP", function() require("fzf-lua").builtin() end, desc = "Pickers" },
    { "<leader>fh", function() require("fzf-lua").help_tags() end, desc = "Help" },
    { "<leader>fo", function() require("fzf-lua").oldfiles() end, desc = "Old Files" },
    { "<leader>fT", function() require("fzf-lua").tabs() end, desc = "Tabs" },

  },
}

