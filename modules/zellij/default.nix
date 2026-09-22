{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.zellij;

  sessionizerVersion = "0.2.0";
  sessionizerUrl = "https://github.com/cunialino/zellij-sessionizer/releases/download/v${sessionizerVersion}/sessionizer.wasm";
in
{
  options.modules.zellij.enable = mkEnableOption "zellij";

  config = mkIf cfg.enable {
    programs.zellij = {
      enable = true;

      # The status bar comes from nixpkgs (pinned with the flake input) instead of a
      # runtime download. home-manager symlinks it to
      # ~/.config/zellij/plugins/zjstatus.wasm and registers the `zjstatus` alias,
      # which is what the layouts in ./layouts reference.
      plugins = [ pkgs.zellijPlugins.zjstatus ];

      settings = {
        plugins = {
          # options for the nixpkgs-provided zellij plugin
          zjstatus = {
            format_left = "{mode}{tabs}";

            hide_frame_for_single_pane = "true";

            tab_normal = "#[fg=#6C7086] {name} ";
            tab_active = "#[fg=#9399B2,bold,italic] {name} ";

            command_git_branch_command = "git rev-parse --abbrev-ref HEAD";
            command_git_branch_format = "#[fg=blue] {stdout} ";
            command_git_branch_interval = "10";
            command_git_branch_rendermode = "static";

            mode_locked = "#[fg=red] {name} ";
            mode_normal = "#[fg=black] {name} ";
            mode_resize = "#[fg=orange] {name} ";
            mode_pane = "#[fg=blue] {name} ";
            mode_tab = "#[fg=blue] {name} ";
            mode_scroll = "#[fg=blue] {name} ";
            mode_enter_search = "#[fg=black] {name} ";
            mode_search = "#[fg=black] {name} ";
            mode_rename_tab = "#[fg=black] {name} ";
            mode_rename_pane = "#[fg=black] {name} ";
            mode_session = "#[fg=black] {name} ";
            mode_move = "#[fg=black] {name} ";
            mode_prompt = "#[fg=black] {name} ";
            mode_tmux = "#[fg=black] {name} ";
          };

          # our own sessionizer plugin (see ./local_bin/zellij_sessionizer.sh)
          sessionizer = {
            _props.location = sessionizerUrl;
            cwd = config.home.homeDirectory;
          };
        };
      };

      # keybinds / theme / behaviour, kept as verbatim KDL
      extraConfig = builtins.readFile ./config.kdl;

      layouts = {
        terminal = ./layouts/terminal.kdl;
        simple = ./layouts/simple.kdl;
      };
    };

    home.file.".local/bin/zellij_sessionizer.sh".source = ./local_bin/zellij_sessionizer.sh;
  };
}
