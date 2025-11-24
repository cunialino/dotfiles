{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.core;
in

{
  options.modules.core.enable = mkEnableOption "core";
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      curl
      wget
      gcc
      uv
      blesh
    ];

    programs.bash = {
      enable = true;
      enableCompletion = true;
      shellAliases = {
        n = "nvim_tmux_opener.sh -l";
        s = "tmux_sessionizer.sh";
      };
      sessionVariables = {
        PATH = "$HOME/.local/bin/:$PATH";
      };
      initExtra = ''
      if [ -f "${pkgs.blesh}/share/blesh/ble.sh" ]; then
        source "${pkgs.blesh}/share/blesh/ble.sh"
      fi

      # Use ble.sh's fzf integration (these scripts are shipped in blesh contrib)
      if [ -f "${pkgs.blesh}/share/blesh/contrib/integration/fzf-initialize.bash" ]; then
        source "${pkgs.blesh}/share/blesh/contrib/integration/fzf-initialize.bash"
      fi
      if [ -f "${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash" ]; then
        source "${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash"
      fi
      '';
    };

    programs.fzf = {
      enable = true;
      enableBashIntegration = false;
    };
    programs.git = {
      enable = true;
      userName = "Elia Cunial";
      userEmail = "elia.cunial@gmail.com";

      difftastic = {
        enable = true;
        enableAsDifftool = true;
        background = "dark";
        color = "auto";
        display = "side-by-side";
      };

      extraConfig = {
        credential.helper = "cache";

        filter.lfs = {
          process = "git-lfs filter-process";
          required = true;
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
        };

        init.defaultBranch = "main";
      };

      includes = [
        {
          path = "~/WORK/.gitconfig";
          condition = "gitdir:~/WORK/";
        }
      ];

    };
  };
}
