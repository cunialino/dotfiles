{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let

  cfg = config.modules.nvim;

  myPlugins = with pkgs.vimPlugins; [
    CopilotChat-nvim
    conform-nvim
    copilot-lua
    dashboard-nvim
    diffview-nvim
    fzf-lua
    gitsigns-nvim
    hardtime-nvim
    lazydev-nvim
    nvim-autopairs
    nvim-dap
    nvim-dap-ui
    nvim-lint
    nvim-nio
    nvim-notify
    otter-nvim
    plenary-nvim
    undotree
    which-key-nvim
    zk-nvim
    {
      name = "LuaSnip";
      path = luasnip;
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

  treesitterLib = import ./treesitter-wrapper.nix { inherit pkgs; };
  grammars = with pkgs.tree-sitter-grammars; [
    tree-sitter-bash
    tree-sitter-c
    tree-sitter-dockerfile
    tree-sitter-html
    tree-sitter-jsdoc
    tree-sitter-json
    tree-sitter-lua
    tree-sitter-markdown
    tree-sitter-markdown-inline
    tree-sitter-nu
    tree-sitter-python
    tree-sitter-query
    tree-sitter-regex
    tree-sitter-rust
    tree-sitter-toml
    tree-sitter-vim
    tree-sitter-yaml
  ];
  treesitterGrammars = treesitterLib.mkTreesitterDir grammars;
in
{

  options.modules.nvim = {
    enable = mkEnableOption "nvim";
  };
  config = mkIf cfg.enable {

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
        terraform-ls
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
        vim.opt.runtimepath:append("${treesitterGrammars}")
      '';

    };
    home.file.".config/nvim/lua".source = ./conf/lua;
    home.file.".config/nvim/lsp".source = ./conf/lsp;
  };
}
