{
  lib,
  config,
  pkgs,
  inputs,
  sys_dir,

  ...
}:

let
  # choose kernel package set that has up-to-date DTBs for sun50i-h618
  kernelPkgs = pkgs.linuxPackages_latest; # change if you want to pin/build a specific kernel
  username = "elia";
  eth = "end0";

  filesystems = pkgs.lib.mkForce [
    "vfat"
    "ntfs"
    "cifs"
    "ext4"
    "vfat"
  ];
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    sys_dir
  ];

  config = {

    modules = {
      k3s_node = {
        enable = true;
        eth = eth;
        role = "agent";
        ip = "192.168.0.4";
      };
    };

    boot.kernelPackages = kernelPkgs;
    hardware.enableRedistributableFirmware = true; # if you need Wi-Fi/BT blobs

    # build an sdImage and inject the board-specific U-Boot SPL into the raw image
    sdImage = {
      compressImage = false; # easier for these boards and dd placement
      postBuildCommands = ''
        dd if=${pkgs.ubootOrangePiZero3}/u-boot-sunxi-with-spl.bin of=$img bs=1024 seek=8 conv=notrunc
      '';
    };

    users.users.${username} = {
      initialPassword = "changeme";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPKPt5/R03Ivma94RuLK4e6vwgwiQbV/jMcvkVbpqGT elia@elcungem"
      ];
    };

    networking.interfaces = {
      ${eth} = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.0.4";
            prefixLength = 24;
          }
        ];
      };
    };

    boot.initrd.supportedFilesystems = filesystems;
    boot.supportedFilesystems = filesystems;

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      interfaces = {
        ${eth} = {
          allowedTCPPorts = [
            22
            6443
            10250
          ];
        };
      };
    };

    nix.settings.trusted-users = [ "elia" ];
    networking.timeServers = [ "192.168.0.2" ];

  };

}
