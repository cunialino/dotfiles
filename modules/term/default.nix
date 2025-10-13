{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.term;
in
{
  options.modules.term.enable = mkEnableOption "term";
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      difftastic
      du-dust
      fd
      fzf
      just
      ripgrep
      sd
      television
      vulnix
    ];

    programs.bat.enable = true;
    programs.k9s.enable = true;

    home.file.".local/bin/zellij_sessionizer.sh".source = ./local_bin/zellij_sessionizer.sh;
    home.file.".local/bin/nvim_tmux_opener.sh".source = ./local_bin/nvim_tmux_opener.sh;

    programs.lazygit = {
      enable = true;
      settings.git.paging = {
        colorArg = "always";
        externalDiffCommand = "difft --color=always";
      };
    };
    programs.bottom = {
      enable = true;

      settings = {
        processes.columns = [
          "cpu%"
          "mem%"
          "gmem%"
          "gpu%"
          "name"
          "state"
          "user"
          "time"
        ];
        flags = {
          enable_gpu_memory = true;
        };

        row = [
          {
            ratio = 30;
            child = [
              { type = "cpu"; }
            ];
          }
          {
            ratio = 30;
            child = [
              { type = "mem"; }
            ];
          }
          {
            ratio = 30;
            child = [
              { type = "proc"; }
            ];
          }
        ];
      };
    };

    programs.zk = {
      enable = true;

      settings = {
        notebook = {
          dir = "~/builds/Ohara/";
        };

        note = {
          language = "en";
          default-title = "Untitled";
          filename = "{{slug title}}";
          extension = "md";
          template = "default.md";
          id-charset = "alphanum";
          id-length = 4;
          id-case = "lower";
        };

        group = {
          daily = {
            note = {
              filename = "{{format-date now 'journal/daily/%Y/%m-%B/%Y-%m-%d'}}";
              template = "daily.md";
            };
          };

          journal = {
            paths = [
              "journal/weekly"
              "journal/daily"
            ];
            note = {
              filename = "{{format-date now}}";
            };
          };
        };

        extra = {
          author = "EC";
        };

        format = {
          markdown = {
            hashtags = true;
            colon-tags = true;
            multi-word-tags = true;
          };
        };

        tool = {
          editor = "nvim";
          shell = "/bin/bash";
          pager = "less -FIRX";
          fzf-preview = "bat -p --color always {-1}";
        };

        filter = {
          recents = "--sort created- --created-after 'last two weeks'";
        };

        alias = {
          edlast = "zk edit --limit 1 --sort modified- $@";
          recent = "zk edit --sort created- --created-after 'last two weeks' --interactive";
          lucky = "zk list --quiet --format full --sort random --limit 1";
          daily = "zk new --group daily";
        };

        lsp = {
          diagnostics = {
            wiki-title = "hint";
            dead-link = "error";
          };
        };
      };
    };

    home.file.".config/zk/templates".source = ./zk/templates;

    programs.starship = {
      enable = true;

      enableNushellIntegration = true;
      settings = {
        format = ''
          [╭─ ](surface2)$hostname$directory$git_branch$git_status$git_state$package
          [╰─ ](surface2)[❯](green) '';
        right_format = "$aws$python$cmd_duration$lua";

        aws = {
          symbol = " ";
          format = "[$symbol($profile )(\\($region\\) )(\\[$duration\\] )]($style)";
          force_display = true;
        };

        directory = {
          home_symbol = " ";
          read_only = " 󰌾";
          style = "bold sapphire";
          substitutions = {
            " /Downloads" = "";
            " /Documents" = "󰈙";
            " /Music" = "";
            " /wallpapers" = "";
            " /WORK/" = ": ";
            " /WORK" = "";
          };
        };

        docker_context.symbol = " ";

        git_branch = {
          symbol = " ";
          style = "bold green";
        };

        git_status = {
          format = ''$all_status$behind$ahead'';
          behind = "[ \${behind_count}](green) ";
          ahead = "[ \${ahead_count}](green) ";
          conflicted = "[󰞇 \${count}](red) ";
          untracked = "[ \${count}](blue) ";
          modified = "[ \${count}](peach) ";
          staged = "[ \${count}](yellow) ";
          renamed = "[󰑕 \${count}](green) ";
          deleted = "[󰚃 \${count}](maroon) ";
          stashed = "[ \${count}](green) ";
        };

        hostname.ssh_symbol = " ";
        lua.symbol = " ";

        package = {
          symbol = "󰏗 ";
          style = "bold maroon";
        };

        python = {
          symbol = " ";
          format = "[\${symbol}\${pyenv_prefix}(\${version} )(\\($virtualenv\\) )]($style)";
        };
      };
    };
    programs.yazi = {
      enable = true;

      initLua = ./yazi/init.lua;
      keymap = {
        mgr.prepend_keymap = [
          {
            on = [
              "z"
              "s"
            ];
            run = "shell --block 'zellij_sessionizer.sh $0'";
            desc = "Start New session in selected dir";
          }
          {
            on = [
              "t"
            ];
            run = [
              "shell 'nvim_tmux_opener.sh -o $1'"
              "quit"
            ];
            desc = "Open with neovim server";
          }

        ];
      };

      plugins = {
        "no-status" = pkgs.yaziPlugins.no-status;
        "starship" = pkgs.yaziPlugins.starship;
      };

    };

    programs.zellij = {
      enable = true;
    };

    home.file.".config/zellij".source = ./zellij;

    programs.nushell = {
      enable = true;
      configFile.source = ./nushell/config.nu;
      envFile.source = ./nushell/env.nu;
      loginFile.source = ./nushell/login.nu;
    };

    home.file.".config/nushell/scripts".source = ./nushell/scripts;

    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
