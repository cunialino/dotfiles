{
  pkgs,
  lib,
  config,
  sys_dir,
  ...
}:
let
  username = "elia";
  eth = "enp0s20u3";
  wlp = "wlp2s0";
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
        ip = "192.168.0.3";
        wlp = wlp;
      };
    };

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
    networking.wireless.enable = true;

    networking.firewall = {
      enable = true;
      checkReversePath = "loose";
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      interfaces.${eth}.allowedTCPPorts = [ 22 ];
      trustedInterfaces = [
        "tailscale0"
      ];
    };
    networking.nat = {
      enable = true;
      externalInterface = wlp;
      internalInterfaces = [ eth ];
      internalIPs = [ "192.168.0.0/24" ];
    };
    services.keepalived = {
      enable = true;
      vrrpInstances.gateway = {
        interface = eth;
        state = "BACKUP";
        virtualRouterId = 51;
        priority = 90;
        virtualIps = [ { addr = "192.168.0.111/24"; } ];
      };
    };
    networking.nftables.tables."tailscale-gateway" = {
      family = "ip";
      content = ''
        chain postrouting {
          type nat hook postrouting priority 100; policy accept;

          # This is the magic: masquerade LAN traffic leaving via Tailscale
          ip saddr 192.168.0.0/24 oifname "tailscale0" masquerade
          
          # Keep your existing K3s/Cilium NAT if needed
          ip saddr 10.42.0.0/16 oifname "tailscale0" masquerade
        }
      '';
    };

    networking.interfaces = {
      ${eth} = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.0.3";
            prefixLength = 24;
          }
        ];
      };
    };
    networking.localCommands = ''
      ${pkgs.iproute2}/bin/ip rule add to 10.42.0.0/16 lookup main priority 2500 || true
      ${pkgs.iproute2}/bin/ip rule add to 10.43.0.0/16 lookup main priority 2501 || true
    '';
    services.tailscale = {
      enable = true;
    };
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];
    nix.settings.trusted-users = [ "elia" ];

    services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  };

}
