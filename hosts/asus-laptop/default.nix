{
  pkgs,
  catppuccin,
  mod_dir,
  sys_dir,
  ...
}:
let
  username = "elia";
in
{
  imports = [
    ./hardware-config.nix
    (import (sys_dir + "/common") {
      username = username;
    })
  ];

  programs.dconf.enable = true;

  home-manager.users.${username} = {
    imports = [
      (mod_dir + "/common")
      (mod_dir + "/gui")
      (mod_dir + "/core")
      (mod_dir + "/term")
      (mod_dir + "/nvim")
      catppuccin.homeModules.catppuccin
    ];
  };

  programs.bash.interactiveShellInit = ''
    if ! [ "$TERM" = "dumb" ]; then
      exec nu
    fi
  '';

  users.users.${username}.shell = pkgs.nushell;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "elcunal";
  networking.wireless.enable = true;
}

