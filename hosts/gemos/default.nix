{
  lib,
  pkgs,
  catppuccin,
  mod_dir,
  sys_dir,
  ...
}:
let
  username = "elia";
  eth = "enp3s0";
in
{
  imports = [
    ./hardware-config.nix
    (import (sys_dir + "/k3s") {
      inherit lib;
      inherit pkgs;
      main_user = username;
      k3s_role = "server";
      eth = eth;
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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.${username} = {
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfXbFJzHbBlJ6ZhoRoC61UJswWK72bpUA5Diuh1BXGB elia.cunial@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdiGofoKxe+4M7tE3E8MtIgJTfo12A3eYP29MSwXdTR elia@NWB005CD2037MQ5"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII0VDOZnoxcXnawqGPqO7OtReAwUZt4124xztbZp4r2c elia.cunial@gmail.com"
    ];
  };

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
    interfaces = {
      ${eth} = {
        allowedTCPPorts = [ 123 ];
        allowedUDPPorts = [ 123 ];
      };
    };
  };
  networking.interfaces = {
    ${eth} = {
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
    openFirewall = false;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
  services.tailscale.enable = true;

  services.ntp.enable = true;
  services.ntp.servers = [
    "0.pool.ntp.org"
    "1.pool.ntp.org"
    "2.pool.ntp.org"
  ];

}
