{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.tmux;
in
{
  options.modules.tmux.enable = mkEnableOption "tmux";
  config = mkIf cfg.enable {

    programs.tmux = {
      enable = true;

      # Basic usability tweaks
      mouse = false;
      historyLimit = 10000; # a larger scrollback
      keyMode = "vi";
      escapeTime = 10;
      prefix = "C-Space";

      # Plugins: use some commonly useful ones
      plugins = with pkgs.tmuxPlugins; [
        sensible
        vim-tmux-navigator
        yank
        fingers
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '15'  # in minutes
          '';
        }
      ];

      extraConfig = ''

        set -ga terminal-overrides ",xterm-256color:Tc"

        set -g set-clipboard on
        set -g allow-passthrough on


        bind T new-window
        bind M-h resize-pane -L 5
        bind M-j resize-pane -D 5
        bind M-k resize-pane -U 5
        bind M-l resize-pane -R 5
        bind | split-window -h
        bind - split-window -v
        bind y new-window "yazi; tmux select-window -t !"
        bind g new-window "lazygit; tmux select-window -t !"
        bind-key s display-popup -E "tmux_sessionizer.sh"

      '';
    };
    home.file.".local/bin/tmux_sessionizer.sh".source = ./sessions.sh;
  };

}
