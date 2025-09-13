{
  config,
  lib,
  pkgs,
  nixgl,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      google-chrome
      noto-fonts-color-emoji
    ]
    ++ (with pkgs.nerd-fonts; [ sauce-code-pro ]);

  home.file.".local/share/applications/gc.desktop".source = ./google-chrome.desktop;

  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      monospace = [ "Sauce Code Pro Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  home.activation = {
    refresh-font-cache = lib.hm.dag.entryAfter [ "installPackages" ] ''
      ${pkgs.fontconfig}/bin/fc-cache -f -v
    '';
  };

  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        font = "monospace:size=12";
      };

      mouse = {
        hide-when-typing = "yes";
      };
    };
  };

  gtk = {
    enable = true;

    font = {
      name = "monospace";
      size = 11;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  nixGL.packages = nixgl.packages;

  nixGL.defaultWrapper = "mesa";
  nixGL.installScripts = [ "mesa" ];

  wayland.windowManager.sway = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.swayfx;
    checkConfig = false;
    systemd.enable = false;
    config = {
      modifier = "Mod4";

      fonts = {
        names = [ "monospace" ];
        size = 12.0;
      };

      gaps = {
        inner = 15;
      };

      bars = [
        {
          command = "waybar";
        }
      ];

      input = {
        "type:keyboard" = {
          xkb_layout = "it";
        };
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          scroll_factor = "0.5";
        };
      };

      output."*" = {
        background = "${config.home.homeDirectory}/.wallpaper fill";
      };

      keybindings = lib.mkOptionDefault {
        "${config.wayland.windowManager.sway.config.modifier}+Return" = "exec foot";
        "${config.wayland.windowManager.sway.config.modifier}+d" = "exec rofi -show drun";

        "${config.wayland.windowManager.sway.config.modifier}+Shift+q" = "kill";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+S" = "sticky enable";

        "${config.wayland.windowManager.sway.config.modifier}+j" = "focus down";
        "${config.wayland.windowManager.sway.config.modifier}+k" = "focus up";
        "${config.wayland.windowManager.sway.config.modifier}+h" = "focus left";
        "${config.wayland.windowManager.sway.config.modifier}+l" = "focus right";
        "${config.wayland.windowManager.sway.config.modifier}+semicolon" = "focus right";
        "${config.wayland.windowManager.sway.config.modifier}+Left" = "focus left";
        "${config.wayland.windowManager.sway.config.modifier}+Down" = "focus down";
        "${config.wayland.windowManager.sway.config.modifier}+Up" = "focus up";
        "${config.wayland.windowManager.sway.config.modifier}+Right" = "focus right";

        "${config.wayland.windowManager.sway.config.modifier}+Shift+j" = "move left";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+k" = "move down";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+l" = "move up";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+h" = "move right";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+Left" = "move left";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+Down" = "move down";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+Up" = "move up";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+Right" = "move right";

        "${config.wayland.windowManager.sway.config.modifier}+Shift+v" = "split v";
        "${config.wayland.windowManager.sway.config.modifier}+v" = "split h";

        "${config.wayland.windowManager.sway.config.modifier}+f" = "fullscreen toggle";
        "${config.wayland.windowManager.sway.config.modifier}+s" = "layout stacking";
        "${config.wayland.windowManager.sway.config.modifier}+w" = "layout tabbed";
        "${config.wayland.windowManager.sway.config.modifier}+e" = "layout toggle split";

        "${config.wayland.windowManager.sway.config.modifier}+Shift+space" = "floating toggle";
        "${config.wayland.windowManager.sway.config.modifier}+space" = "focus mode_toggle";

        "${config.wayland.windowManager.sway.config.modifier}+a" = "focus parent";

        "${config.wayland.windowManager.sway.config.modifier}+1" = "workspace number 1";
        "${config.wayland.windowManager.sway.config.modifier}+2" = "workspace number 2";
        "${config.wayland.windowManager.sway.config.modifier}+3" = "workspace number 3";
        "${config.wayland.windowManager.sway.config.modifier}+4" = "workspace number 4";
        "${config.wayland.windowManager.sway.config.modifier}+5" = "workspace number 5";
        "${config.wayland.windowManager.sway.config.modifier}+6" = "workspace number 6";
        "${config.wayland.windowManager.sway.config.modifier}+7" = "workspace number 7";
        "${config.wayland.windowManager.sway.config.modifier}+8" = "workspace number 8";
        "${config.wayland.windowManager.sway.config.modifier}+9" = "workspace number 9";
        "${config.wayland.windowManager.sway.config.modifier}+0" = "workspace number 10";

        "${config.wayland.windowManager.sway.config.modifier}+Shift+1" =
          "move container to workspace number 1";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+2" =
          "move container to workspace number 2";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+3" =
          "move container to workspace number 3";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+4" =
          "move container to workspace number 4";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+5" =
          "move container to workspace number 5";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+6" =
          "move container to workspace number 6";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+7" =
          "move container to workspace number 7";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+8" =
          "move container to workspace number 8";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+9" =
          "move container to workspace number 9";
        "${config.wayland.windowManager.sway.config.modifier}+Shift+0" =
          "move container to workspace number 10";

        "${config.wayland.windowManager.sway.config.modifier}+Shift+c" = "reload";

        "${config.wayland.windowManager.sway.config.modifier}+r" = "mode resize";

        "XF86AudioLowerVolume" = "exec pamixer -d 5";
        "XF86AudioRaiseVolume" = "exec pamixer -i 5";
        "XF86AudioMute" = "exec pamixer -t";

        "XF86MonBrightnessDown" = "exec light -U 5";
        "XF86MonBrightnessUp" = "exec light -A 5";

        "${config.wayland.windowManager.sway.config.modifier}+u" = "workspace prev";
        "${config.wayland.windowManager.sway.config.modifier}+o" = "workspace next";
      };

      window = {
        border = 0;
        titlebar = false;

        commands = [
          {
            criteria = {
              title = "^[Pp]icture\\s?-?in\\s?-?[Pp]icture$";
            };
            command = "floating enable, resize set 600px 340px, sticky enable, move position 1290px 675px, opacity 0.2, blur disable";
          }
          {
            criteria = {
              app_id = "google-chrome";
            };
            command = "move to workspace number 2";
          }
          {
            criteria = {
              app_id = ".*";
            };
            command = "opacity 0.8";
          }
        ];
      };

      modes = {
        resize = {
          j = "resize shrink width 10 px or 10 ppt";
          k = "resize grow height 10 px or 10 ppt";
          l = "resize shrink height 10 px or 10 ppt";
          semicolon = "resize grow width 10 px or 10 ppt";

          Left = "resize shrink width 10 px or 10 ppt";
          Down = "resize grow height 10 px or 10 ppt";
          Up = "resize shrink height 10 px or 10 ppt";
          Right = "resize grow width 10 px or 10 ppt";

          Return = "mode default";
          Escape = "mode default";
        };
      };

      defaultWorkspace = "workspace number 1";
      startup = [
        { command = "pipewire"; }
      ];

    };

    extraConfig = ''
      hide_edge_borders both
      corner_radius 10
      blur enable
    '';
  };

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
  };
}
