{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # choose kernel package set that has up-to-date DTBs for sun50i-h618
  kernelPkgs = pkgs.linuxPackages_latest; # change if you want to pin/build a specific kernel
  username = "elia";
  homedir = "/home/${username}";
  stateVersion = "25.05";
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  networking.hostName = "opizero3";
  system.stateVersion = stateVersion;

  # kernel / firmware
  boot.kernelPackages = kernelPkgs;
  hardware.enableRedistributableFirmware = true; # if you need Wi-Fi/BT blobs

  # build an sdImage and inject the board-specific U-Boot SPL into the raw image
  sdImage = {
    enable = true;
    compressImage = false; # easier for these boards and dd placement
  };

  users.users.youruser = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
  };
}
