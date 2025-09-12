{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    bottom
    difftastic
    du-dust
    fd
    just
    nushell
    ripgrep
    sd
    starship
    television
    vulnix
    yazi
    zellij
  ];

  programs.bat.enable = true;

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

}
