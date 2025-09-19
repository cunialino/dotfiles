{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # choose kernel package set that has up-to-date DTBs for sun50i-h618
  username = "elia";
  homedir = "/home/${username}";
  stateVersion = "25.05";
  hostPkgs = import inputs.nixpkgs { system = "x86_64-linux"; };

  # cross is the "aarch64" cross-target package set available on the host
  cross = hostPkgs.pkgsCross.aarch64-multiplatform;

  # choose kernel package set from the cross set (so the host knows how to build/resolve it)
  kernelPkgsCross = cross.linuxPackages_latest;
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  networking.hostName = "opizero3";
  system.stateVersion = stateVersion;

  boot.kernelPackages = kernelPkgsCross;
  hardware.enableRedistributableFirmware = true; # if you need Wi-Fi/BT blobs

  # build an sdImage and inject the board-specific U-Boot SPL into the raw image
  sdImage = {
    compressImage = false; # easier for these boards and dd placement
  };

  users.users.${username} = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [
      "wheel"
      "k3s"
    ];
    home = homedir;
    shell = pkgs.nushell;

  };
}
