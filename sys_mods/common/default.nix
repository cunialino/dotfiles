{ ... }:
let
  username = "elia";
  homedir = "/home/${username}";
  stateVersion = "25.05";
in
{

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

}
