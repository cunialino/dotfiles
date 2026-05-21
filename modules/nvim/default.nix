{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let

  cfg = config.modules.nvim;

  noCheck = pkg: pkg.overrideAttrs { doCheck = false; };
  jupynvim =
    let
      repo = "sheng-tse/jupynvim";
      rev = "667d7c4018a7bbc72b88d68e96be59ab86f5b044";

      # Using fetchFromGitHub is highly recommended over builtins.fetchGit here,
      # as buildRustPackage requires a stable store path to calculate cargo dependencies.
      src = pkgs.fetchFromGitHub {
        owner = "sheng-tse";
        repo = "jupynvim";
        inherit rev;
        # Update this to the correct source hash
        hash = "sha256-jpReQW9tyOrSsBJLE3IPFNG/IwWZ051j+3gAI1xibj0=";
      };

      jupynvim-core = pkgs.rustPlatform.buildRustPackage {
        pname = "jupynvim-core";
        version = "main";
        inherit src;

        # Here is the crucial fix: pointing to the 'core' directory
        sourceRoot = "source/core";

        # Update this to the correct cargo dependencies hash
        cargoHash = "sha256-sdmye61uTqHHbqlG2yj8lKZUu1q1Iir969t8MU2OJbM=";
      };
    in
    pkgs.vimUtils.buildVimPlugin {
      pname = "${lib.strings.sanitizeDerivationName repo}";
      version = "main";
      inherit src;

      # The Lua script likely looks for the built binary in core/target/release/
      # We recreate that path and link the compiled binary there so Neovim can find it.
      postInstall = ''
        mkdir -p $out/core/target/release
        ln -s ${jupynvim-core}/bin/* $out/core/target/release/
      '';
    };

  myPlugins =
    with pkgs.vimPlugins;
    map noCheck [
      conform-nvim
      diffview-nvim
      fzf-lua
      gitsigns-nvim
      lazydev-nvim
      nvim-autopairs
      nvim-dap
      nvim-dap-ui
      nvim-lint
      nvim-nio
      nvim-notify
      plenary-nvim
      which-key-nvim
      zk-nvim
    ]
    ++ [
      {
        name = "surround.nvim";
        path = surround-nvim;
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
    home.packages = with pkgs.python313Packages; [
      debugpy
      python-lsp-server
      pylsp-rope
    ];
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      extraPackages = with pkgs; [
        lua-language-server
        yaml-language-server
        nil
        nixfmt
        terraform-ls
        sqlfluff
        typos
        ty
      ];
      plugins = with pkgs.vimPlugins; [
        lazy-nvim
        luasnip
        blink-cmp
        jupynvim
      ];
      initLua = ''

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
        vim.opt.runtimepath:append("${treesitterGrammars}")
      '';

    };
    home.file.".config/nvim/lua".source = ./conf/lua;
    home.file.".config/nvim/lsp".source = ./conf/lsp;
  };
}
