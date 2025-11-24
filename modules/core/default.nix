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
    };
    programs.carapace = {
      enable = true;
      enableBashIntegration = true;
    };

    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
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
