{
  config,
  lib,
  pkgs,
  nixgl,
  ...
}:
with lib;
let
  cfg = config.modules.gui;

  # Static bash script (see sway-wallpaper.sh), patched to a store bash so it
  # also runs from sway's `exec`, where PATH is whatever sway happened to inherit.
  wallpaperScript = pkgs.runCommand "sway-wallpaper" { } ''
    mkdir -p $out/bin
    cp ${./sway-wallpaper.sh} $out/bin/sway-wallpaper
    chmod +x $out/bin/sway-wallpaper
    patchShebangs $out/bin/sway-wallpaper
  '';
in
{
  options.modules.gui.enable = mkEnableOption "gui";

  options.modules.gui.wallpaper = {
    dir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/wallpapers";
      description = ''
        Directory the rotation cycles through. Deliberately outside this repo:
        the wallpapers themselves never reach git.
      '';
    };

    intervalMinutes = mkOption {
      type = types.ints.positive;
      default = 15;
      description = "How long each wallpaper stays up while rotating.";
    };

    toggleKey = mkOption {
      type = types.str;
      default = config.wayland.windowManager.sway.config.modifier + "+Shift+w";
      defaultText = "<modifier>+Shift+w";
      description = "Keybinding that switches between the fixed wallpaper and the rotation.";
    };

    defaultImage = mkOption {
      type = types.str;
      default = "${./wallpapers/wally.png}";
      defaultText = "./wallpapers/wally.png";
      description = ''
        The wallpaper sway shows on a cold boot and whenever the rotation is off.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        wallpaperScript
        firefox
        wireplumber
        wl-clipboard
        noto-fonts
        noto-fonts-color-emoji
      ]
      ++ (with pkgs.nerd-fonts; [ sauce-code-pro ]);

    home.file.".local/share/applications/firefox.desktop".source = ./firefox.desktop;

    home.file.".config/sway-wallpaper/config".text = ''
      WALLPAPER_DIR="${cfg.wallpaper.dir}"
      WALLPAPER_INTERVAL_SECS="${toString (cfg.wallpaper.intervalMinutes * 60)}"
      WALLPAPER_DEFAULT="${cfg.wallpaper.defaultImage}"
      WALLPAPER_EXTRA_PATH="${
        lib.makeBinPath [
          config.wayland.windowManager.sway.package
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.util-linux
        ]
      }"
    '';

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
      # The external wallpaper dir has to exist before there is anything to put in it.
      create-wallpaper-dir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${lib.escapeShellArg cfg.wallpaper.dir}
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

    targets.genericLinux.nixGL.packages = nixgl.packages;

    targets.genericLinux.nixGL.defaultWrapper = "mesa";
    targets.genericLinux.nixGL.installScripts = [ "mesa" ];

    # Everything Wayland that is managed by systemd hangs off this target, which
    # sway brings up itself (see the systemd block below). Without it a unit like
    # swaync's is WantedBy a target that never starts, i.e. silently dead.
    wayland.systemd.target = "sway-session.target";

    wayland.windowManager.sway = {
      enable = true;
      package = config.lib.nixGL.wrap pkgs.swayfx;
      checkConfig = false;
      # sway-session.target, started by sway and stopped when sway exits: the
      # startup line sway runs imports WAYLAND_DISPLAY & co into the systemd/D-Bus
      # user environment, `reset-failed`, starts the target, then blocks in
      # `swaymsg subscribe '[]'` until sway dies and stops it again. So Wayland
      # services start with the compositor and take their turn down with it --
      # and a failed one is reset on the next sway start instead of staying dead.
      systemd.enable = true;
      # This host runs dbus-broker (NixOS services.dbus.implementation), so use
      # `systemctl --user import-environment` rather than dbus-update-activation-environment.
      systemd.dbusImplementation = "broker";
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
          background = "${cfg.wallpaper.defaultImage} fill";
        };

        startup = [
          # Reload/restart re-applies `output * background`, which would drop the
          # rotation for one interval; this puts it straight back if it is on.
          {
            command = "sway-wallpaper resume";
            always = true;
          }
        ];

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

          "XF86AudioLowerVolume" = "exec wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

          "XF86MonBrightnessDown" = "exec light -U 5";
          "XF86MonBrightnessUp" = "exec light -A 5";

          "${config.wayland.windowManager.sway.config.modifier}+u" = "workspace prev";
          "${config.wayland.windowManager.sway.config.modifier}+o" = "workspace next";

          "${cfg.wallpaper.toggleKey}" = "exec sway-wallpaper toggle";

          # -sw: start swaync if the unit has not got it up yet, -t: toggle the
          # control centre (it is also the notification window's only UI).
          "${config.wayland.windowManager.sway.config.modifier}+n" = "exec swaync-client -t -sw";
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
                app_id = "firefox";
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
      };

      extraConfig = ''
        hide_edge_borders both
        corner_radius 10
        blur enable
      '';
    };

    # The notification daemon. Styling is catppuccin's job (autoEnable hands
    # services.swaync.style to catppuccin/nix, so setting `style` here would be
    # a conflicting assignment); this is behaviour only.
    services.swaync = {
      enable = true;

      settings = {
        positionX = "right";
        positionY = "top";

        # Notifications float (overlay), the control centre sits above them. No
        # exclusive zone is requested either, which matters in the top-right: a
        # zone would push waybar's pill and relayout every workspace.
        layer = "overlay";
        control-center-layer = "top";
        layer-shell = true;

        # swaync's own style.css has to win over the catppuccin *gtk* theme, which
        # is otherwise loaded from ~/.config/gtk-4.0/gtk.css.
        cssPriority = "user";
        ignore-gtk-theme = true;

        fit-to-screen = false;
        control-center-width = 480;
        control-center-height = 860;
        notification-window-width = 460;

        # ntfy priority 4+ arrives as urgency critical (libnotify has nothing
        # between normal and critical), which swaync then keeps on screen until
        # dismissed -- that is the point of "a human is needed", and it is why
        # ordinary messages must not linger either.
        timeout = 10;
        timeout-low = 5;
        timeout-critical = 0;

        notification-2fa-action = true;
        notification-inline-replies = false;
        notification-body-image-height = 160;
        notification-body-image-width = 440;

        relative-timestamps = true;
        hide-on-clear = false;
        hide-on-action = true;
        text-empty = "Nothing";

        widgets = [
          "title"
          "dnd"
          "notifications"
        ];
        widget-config = {
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = "Clear";
          };
          dnd.text = "Do Not Disturb";
          notifications.vexpand = true;
        };
      };
    };

    # The waybar CSS in this module is hand-written, so the notification centre
    # gets the same font as the bar rather than catppuccin's default.
    catppuccin.swaync = {
      font = "SauceCodePro Nerd Font";
      fontSize = "13";
    };

    # Pushes that only ever reach a phone are useless while sitting at the
    # machine, and the rig publishes to ntfy anyway (modules.herdr).
    modules.ntfy = {
      enable = lib.mkDefault true;
      # Read the publishing topic too, so the agent queue's "needs a human"
      # pushes show up on screen as well as on the phone. Same file, still never
      # in the repo. mkOptionDefault because list options *replace* their default
      # on the first definition: plain assignment here would silently drop the
      # module's own ~/.config/ntfy/topics.
      topicFiles = lib.mkIf config.modules.herdr.enable (lib.mkOptionDefault [
        config.modules.herdr.queue.ntfyTopicFile
      ]);
    };

    programs.rofi = {
      enable = true;
      package = pkgs.rofi;
    };

    programs.waybar = {
      enable = true;

      settings = {
        mainBar = {
          spacing = 4; # Gaps between modules (4px)

          modules-left = [ "sway/workspaces" ];
          modules-center = [
            "cpu"
            "memory"
            "temperature"
          ];
          modules-right = [
            "network"
            "wireplumber"
            "backlight"
            "battery"
            "clock"
          ];

          "sway/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
            warp-on-scroll = false;
            format = "{icon}";
            format-icons = {
              "1" = "";
              "2" = "";
              "3" = "";
              "4" = "";
              "5" = "";
              urgent = "";
            };
          };

          clock = {
            format = "{:%H:%M}  ";
            format-alt = "{:L%A, %B %d, %Y (%R)}  ";
            tooltip-format = ''
              \n<span size='9pt' font='WenQuanYi Zen Hei Mono'>{calendar}</span>
            '';
            calendar = {
              mode = "year";
              mode-mon-col = 3;
              weeks-pos = "right";
              on-scroll = 1;
              format = {
                months = "<span color='#ffead3'><b>{}</b></span>";
                days = "<span color='#ecc6d9'><b>{}</b></span>";
                weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                today = "<span color='#ff6699'><b><u>{}</u></b></span>";
              };
            };
            actions = {
              on-click-right = "mode";
              on-click-forward = "tz_up";
              on-click-backward = "tz_down";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          cpu = {
            format = "{usage}% ";
            tooltip = false;
          };

          memory = {
            format = "{}% ";
          };

          temperature = {
            critical-threshold = 80;
            format = "{temperatureC}°C {icon}";
            format-icons = [ "" ];
          };

          backlight = {
            # device = "acpi_video1";
            format = "{percent}% {icon}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
            ];
          };

          battery = {
            states = {
              good = 95;
              warning = 30;
              critical = 15;
            };
            format = "{capacity}% {icon}";
            format-charging = "{capacity}% 󰃨";
            format-plugged = "{capacity}% ";
            format-alt = "{time} {icon}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };

          network = {
            interface = "w*";
            format-wifi = "{essid} ({signalStrength}%) 󰖩";
            format-ethernet = "{ipaddr}/{cidr} 󰈁";
            tooltip-format = "{ifname} via {gwaddr} 󰊗";
            format-linked = "{ifname} (No IP) 󱚵";
            format-disconnected = "Disconnected 󰖪";
            format-alt = "{ifname}: {ipaddr}/{cidr}";
          };

          wireplumber = {
            format = "{volume}% {icon} {format_source}";
            format-bluetooth = "{volume}% {icon}  {format_source}";
            format-bluetooth-muted = "󰝟 {icon}  {format_source}";
            format-muted = "󰝟 {format_source}";
            format-source = "{volume}% ";
            format-source-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "󰙌";
              headset = "󰋎";
              phone = "";
              portable = "";
              car = "";
              default = [
                "󰕿"
                "󰖀"
                "󰕾"
              ];
            };
            on-click = "pavucontrol";
          };
        };
      };

      style = ''
        * {
            /* `otf-font-awesome` is required to be installed for icons */
            font-family: SauceCodePro Nerd Font, FontAwesome, Roboto, Helvetica, Arial, sans-serif;
            font-size: 13px;
        }

        window#waybar {
            background-color: transparent;
            color: @text;
            transition-property: background-color;
            transition-duration: .5s;
        }


        #workspaces,
        .modules-right,
        .modules-center {
            background-color: alpha( @base, 0.7 );
            border-radius: 50px;
            border-style: solid;
            border-width: 1px;
            border-color: @accent;
            color: @text;
        }
        #workspaces button:not(:last-child),
        .modules-center widget:not(:last-child),
        .modules-right widget:not(:last-child)
        {
            border-right-style: solid;
            border-right-width: 1px;
            border-right-color: @accent;
        }

        #cpu, #memory, #temperature, #network,
        #pulseaudio, #backlight, #battery, #clock
        {
          padding-left: 10px;
          padding-right: 20px;
        }

        @keyframes blink {
            to {
                color: @crust;
            }
        }

        #workspaces button.focused {
            color: @accent;
            animation-name: blink;
            animation-duration: 1s;
            animation-timing-function: linear;
            animation-iteration-count: infinite;
            animation-direction: alternate;
        }

        #battery.charging  {
            color: @green;
            animation-name: blink;
            animation-duration: 1s;
            animation-timing-function: linear;
            animation-iteration-count: infinite;
            animation-direction: alternate;
        }
        #battery.plugged{
            color: @green;
        }


        #battery.critical:not(.charging),
        #workspaces button.urgent,
        #temperature.critical,
        #network.disconnected
        {
            color: @red;
            animation-name: blink;
            animation-duration: 1s;
            animation-timing-function: linear;
            animation-iteration-count: infinite;
            animation-direction: alternate;
        }


        tooltip {
          background-color: alpha(@base, 0.7);
        }
      '';
    };
  };
}
