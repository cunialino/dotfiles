{
  pkgs,
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

  networking.hostName = "elcungem";
  networking.wireless.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowPing = false;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    trustedInterfaces = [ "tailscale0" ];
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      AllowUsers = [ "elia" ];
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
  services.tailscale.enable = true;
  time.timeZone = "Europe/Rome";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "it";
  };
}
