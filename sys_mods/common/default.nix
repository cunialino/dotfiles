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
