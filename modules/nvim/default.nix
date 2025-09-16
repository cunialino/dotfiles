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

      (nvim-treesitter.withPlugins (p: [
        p.bash
        p.c
        p.diff
        p.dockerfile
        p.html
        p.jsdoc
        p.json
        p.jsonc
        p.lua
        p.luadoc
        p.luap
        p.markdown
        p.markdown_inline
        p.nu
        p.python
        p.query
        p.regex
        p.rust
        p.toml
        p.vim
        p.vimdoc
        p.yaml
      ]))
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
