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
  wlp = "wlp4s0";
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
        is_registry = true;
        cluster_init = true;
        wlp = wlp;
      };

    };
    environment.systemPackages = with pkgs; [
      xfsprogs
    ];
    home-manager.users.${username} = (import ./home.nix);

    programs.dconf.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

    boot.kernelPackages = pkgs.linuxPackages_latest;

    users.users.${username} = {
      isNormalUser = true;
      initialPassword = "changeme";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfXbFJzHbBlJ6ZhoRoC61UJswWK72bpUA5Diuh1BXGB elia.cunial@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII0VDOZnoxcXnawqGPqO7OtReAwUZt4124xztbZp4r2c elia.cunial@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEEd6dzfbpTTkSL/jFX8ImZKELjlVglhpxdPBtVUsVZ+ u0_a231@localhost"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKVPpC5/rNBfc6h0x5+p9h94aAV8i4CNv05XUoC0T8/4 d00f192@MACITGQYW7FXH"
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
        state = "MASTER";
        virtualRouterId = 51;
        priority = 100;
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
    networking.wireless.enable = true;
    networking.nftables.enable = true;
    networking.firewall = {
      enable = true;
      checkReversePath = "loose";
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      trustedInterfaces = [
        "tailscale0"
      ];
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
    networking.localCommands = ''
      ${pkgs.iproute2}/bin/ip rule add to 10.42.0.0/16 lookup main priority 2500 || true
      ${pkgs.iproute2}/bin/ip rule add to 10.43.0.0/16 lookup main priority 2501 || true
    '';
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      wireplumber.enable = true;
    };
    services.tailscale = {
      enable = true;
    };
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];

    services.chrony = {
      enable = true;
      # List your upstream pools
      servers = [
        "0.pool.ntp.org"
        "1.pool.ntp.org"
        "2.pool.ntp.org"
      ];
      extraConfig = ''
        # This is the magic line that lets other machines ask for time
        allow 192.168.0.0/24 
      '';
    };
  };

}
