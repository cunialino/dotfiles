{
  pkgs,
  lib,
  config,
  sys_dir,
  ...
}:
let
  username = "elia";
  eth = "eno1";
in
{
  imports = [
    ./hardware-config.nix
    sys_dir
  ];

  config = {

    modules = {
      k3s_node = {
        enable = true;
        eth = eth;
        role = "server";
        ip = "192.168.0.5";
        wlp = "wlp0s20f0u13";
      };
    };
    environment.systemPackages = with pkgs; [
      xfsprogs
    ];
    home-manager.users.${username} = (import ./home.nix);

    programs.dconf.enable = true;

    users.users.${username} = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPKPt5/R03Ivma94RuLK4e6vwgwiQbV/jMcvkVbpqGT elia@elcungem"
      ];
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.nftables.enable = true;
    networking.wireless.enable = false;
    networking = {
      defaultGateway = {
        address = "192.168.0.111";
        interface = eth;
      };

      nameservers = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      interfaces.${eth}.allowedTCPPorts = [ 22 ];
    };

    networking.interfaces = {
      ${eth} = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.0.5";
            prefixLength = 24;
          }
        ];
      };
    };
    nix.settings.trusted-users = [ "elia" ];
  };

}
