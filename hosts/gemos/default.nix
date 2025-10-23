{
  lib,
  config,
  pkgs,
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
      inherit config;
      main_user = username;
      k3s_role = "server";
      eth = eth;
      k3s_labels = {
        "node.longhorn.io/create-default-disk" = "true";
      };

    })
    (import (sys_dir + "/common") {
      username = username;
    })
    (sys_dir + "/sshd")
  ];

  home-manager.users.${username} = (import ./home.nix);

  programs.dconf.enable = true;

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
  services.tailscale.enable = true;

  services.ntp.enable = true;
  services.ntp.servers = [
    "0.pool.ntp.org"
    "1.pool.ntp.org"
    "2.pool.ntp.org"
  ];

  services.k3s = {

    extraKubeletConfig = {
      systemReserved = {
        cpu = "4";
        memory = "16Gi";
      };
    };
  };

}
