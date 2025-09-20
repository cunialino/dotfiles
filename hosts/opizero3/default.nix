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
    compressImage = false; # easier for these boards and dd placement
    postBuildCommands = ''
      # write SPL+u-boot to the sectors expected by sunxi
      dd if=${pkgs.ubootOrangePiZero3}/u-boot-sunxi-with-spl.bin of=$img bs=1024 seek=8 conv=notrunc
    '';
  };

  users.users.${username} = {
    isNormalUser = true;
    home = homedir;
    extraGroups = [
      "wheel"
    ];
  };
}
