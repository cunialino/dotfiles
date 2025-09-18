{
  config,
  pkgs,
  lib,
  catppuccin,
  ...
}:

let
  username = "elia";
  homedir = "/home/${username}";
  stateVersion = "25.05";
in
{
  environment.systemPackages = with pkgs; [ git ];

  imports = [
    ./hardware-config.nix
  ];

  programs.dconf.enable = true;

  home-manager.users.${username} = {
    imports = [
      ../../modules/common
      ../../modules/gui
      ../../modules/core
      ../../modules/term
      ../../modules/nvim
      catppuccin.homeModules.catppuccin
    ];
    home.stateVersion = stateVersion;
  };

  programs.bash.interactiveShellInit = ''
    if ! [ "$TERM" = "dumb" ]; then
      exec nu
    fi
  '';

  users.users.${username} = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" ];
    home = homedir;
    shell = pkgs.nushell;
  };

  system.stateVersion = stateVersion;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "elcun";
  networking.wireless.enable = true;
  time.timeZone = "Europe/Rome";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "it";
  };

}
