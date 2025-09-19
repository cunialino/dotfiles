{
  pkgs,
  inputs,
  sys_dir,

  ...
}:

let
  # choose kernel package set that has up-to-date DTBs for sun50i-h618
  kernelPkgs = pkgs.linuxPackages_latest; # change if you want to pin/build a specific kernel
  username = "elia";
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    (import (sys_dir + "/common") {
      username = username;
    })

  ];

  networking.hostName = "opizero3";

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
  };

  networking.interfaces = {
    eno1 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.0.4";
          prefixLength = 24;
        }
      ];
    };
  };

}
