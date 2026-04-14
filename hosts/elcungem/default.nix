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
        wlp = "wlp4s0";
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

    networking.wireless.enable = true;
    networking.nftables.enable = true;
    networking.firewall = {
      enable = true;
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
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      wireplumber.enable = true;
    };
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
    };

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
