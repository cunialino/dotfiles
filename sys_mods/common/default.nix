{ config, lib, ... }:
let
  cfg = config.modules.common;
  username = cfg.main_user;
  homedir = "/home/${username}";
  stateVersion = cfg.state_version;
in
{

  options.modules.common = {
    main_user = lib.mkOption {
      type = lib.types.str;
      default = "elia";
      description = "Main user";
    };
    state_version = lib.mkOption {
      type = lib.types.str;
      default = "25.05";
      description = "stateVersion";
    };

  };
  config = {
    environment.pathsToLink = [ "/share/bash-completion" ];
    boot.kernel.sysctl = {
      "net.core.nm_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.core.netdev_max_backlog" = 5000;
      "kernel.watchdog_thresh" = 30;
      "net.ipv4.neigh.default.gc_thresh3" = 8192;
    };
    security.sudo.extraRules = [
      {
        users = [ cfg.main_user ];
        commands = [
          {
            command = "/run/current-system/sw/bin/reboot";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/nix-collect-garbage";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    system.stateVersion = stateVersion;

    home-manager.users.${username} = {
      home.stateVersion = stateVersion;
    };

    users.users.${username} = {
      isNormalUser = true;
      createHome = true;
      extraGroups = [
        "wheel"
      ];
      home = homedir;
    };

    services.openssh = {
      settings = {
        AllowUsers = [ username ];
      };
    };

    time.timeZone = "Europe/Rome";

    console = {
      font = "Lat2-Terminus16";
      keyMap = "it";
    };
  };
}
