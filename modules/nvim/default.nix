{
  lib,
  pkgs,
  ...
}:
let

  myPlugins = with pkgs.vimPlugins; [
    CopilotChat-nvim
    blink-cmp
    blink-cmp-copilot
    conform-nvim
    copilot-lua
    dashboard-nvim
    diffview-nvim
    friendly-snippets
    fzf-lua
    gitsigns-nvim
    hardtime-nvim
    lazydev-nvim
    lualine-nvim
    mini-comment
    nvim-autopairs
    nvim-dap
    nvim-dap-ui
    nvim-lint
    nvim-nio
    nvim-notify
    nvim-treesitter
    nvim-treesitter-parsers.bash
    nvim-treesitter-parsers.c
    nvim-treesitter-parsers.diff
    nvim-treesitter-parsers.dockerfile
    nvim-treesitter-parsers.html
    nvim-treesitter-parsers.jsdoc
    nvim-treesitter-parsers.json
    nvim-treesitter-parsers.jsonc
    nvim-treesitter-parsers.lua
    nvim-treesitter-parsers.luadoc
    nvim-treesitter-parsers.luap
    nvim-treesitter-parsers.markdown
    nvim-treesitter-parsers.markdown_inline
    nvim-treesitter-parsers.nu
    nvim-treesitter-parsers.python
    nvim-treesitter-parsers.query
    nvim-treesitter-parsers.regex
    nvim-treesitter-parsers.rust
    nvim-treesitter-parsers.toml
    nvim-treesitter-parsers.vim
    nvim-treesitter-parsers.vimdoc
    nvim-treesitter-parsers.yaml
    nvim-treesitter-textobjects
    nvim-ts-context-commentstring
    nvim-web-devicons
    plenary-nvim
    undotree
    vim-slime
    which-key-nvim
    yazi-nvim
    zk-nvim
    {
      name = "LuaSnip";
      path = luasnip;
    }
    {
      name = "bufferline.nvim";
      path = bufferline-nvim;
    }
    {
      name = "surround.nvim";
      path = surround-nvim;
    }
    {
      name = "snacks.nvim";
      path = snacks-nvim;
    }
  ];
  mkEntryFromDrv =
    drv:
    if lib.isDerivation drv then
      {
        name = "${lib.getName drv}";
        path = drv;
      }
    else
      drv;
  lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv myPlugins);
in
{
  home.sessionVariables = {
    EDITOR = "nvim";
  };
  home.packages = with pkgs; [ python313Packages.debugpy ];
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      lua-language-server
      nil
      nixfmt
    ];
    plugins = with pkgs.vimPlugins; [
      lazy-nvim
    ];
    extraLuaConfig = ''

        ${builtins.readFile ./conf/init.lua}
        require("lazy").setup({
          spec = {
            { import = "plugins" },
          },
          performance = {
            reset_packpath = false,
            rtp = { reset = false },
          },
          dev = {
            path = "${lazyPath}",
            patterns = { "" },
          },
          install = { missing = false },
        })
      vim.cmd("silent! Copilot disable")
    '';

  };
  home.file.".config/nvim/lua".source = ./conf/lua;
  home.file.".config/nvim/lsp".source = ./conf/lsp;
}
