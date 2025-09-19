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
    (import (sys_dir + "/k3s") {
      main_user = username;
      k3s_role = "server";
    })
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
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "elcungem";
  networking.wireless.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowPing = false;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    trustedInterfaces = [
      "tailscale0"
    ];
  };
  networking.interfaces = {
    eno1 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.0.2";
          prefixLength = 24;
        }
      ];
    };

  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
  services.tailscale.enable = true;
}
