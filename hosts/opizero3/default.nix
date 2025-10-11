{
  lib,
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
    (import (sys_dir + "/common") {
      username = username;
    })

    (import (sys_dir + "/k3s") {
      inherit lib;
      inherit pkgs;
      k3s_role = "agent";
      main_user = username;
      eth = eth;
    })
    (sys_dir + "/sshd")

  ];

  # kernel / firmware
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
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQClmGcdVOIKxGE09mbmqc/RpLgfGnuWIM8jd8ShoSQyFDBnpiorURYOjs14aGw1hp0KPX0jYdN6fd/xoYdCCC0e2GshJnwlkN1OjXfMTjzIqWNa7oSoL6lhBSp22Aq+pY2kk7gL1j8q4WUTBNUcDPQVmnQdZGmhXgNSSNX6RChkEKhmAKtgLsO6FAZL4JcU4uG1o7HGtn9FN2DmYje/J9Q+WFgyYhz03TzCiyLmwsgYuM3lSwT999TztQ8tQtrVyrJcLpuA4gN0KrHidvWGit25m/bR/FD0lcHKkaxkKhBreaBYWzOKA7H8cZr9qdW9zjv9cnadXV92aQde5XZN6tXgf+N3jys2VIXLKkkKFVZ3IuHm6ZLsgY74lCzXmXDFpdzY3zR2qibqyubEBTHnXb04yb3Tgyl13RT/Vq8Sa8c+z2L8eu5o3BeyGu2acYFnn7u+AtSR4HNU5Pi1DPL8k65Us440ywurYfXwZ8qGknNNydEbZDXR+hcDK8RiTWohaWcy9L5jiRpSbgacEAHbm2Nl9BUx6muvjKiOFwhdbw3QBThCqNmSO6JcTLmIZt/uutw2vBwCKTs6i/jImVjPUIIe3vbFviCIsW4MENJglOZbvvfLGZsVXzWF/Wdmv5VAybsoom8iIKhwgZlwsJDzjRl3Yo4QB6ZA3225/p7o/fIsAw== elia.cunial@gmail.com"
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
}
