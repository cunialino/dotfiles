{
  pkgs,
  catppuccin,
  mod_dir,
  ...
}:

let
  username = "elia";
  homedir = "/home/${username}";
  stateVersion = "25.05";
in
{
  environment.systemPackages = with pkgs; [ git ];

  imports = [
    ./hardware-config.nix
  ];

  programs.dconf.enable = true;

  home-manager.users.${username} = {
    imports = [
      (mod_dir + "/common")
      (mod_dir + "/gui")
      (mod_dir + "/core")
      (mod_dir + "/term")
      (mod_dir + "/nvim")
      catppuccin.homeModules.catppuccin
    ];
    home.stateVersion = stateVersion;
  };

  programs.bash.interactiveShellInit = ''
    if ! [ "$TERM" = "dumb" ]; then
      exec nu
    fi
  '';

  users.groups = {
    k3s = { };
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

  system.stateVersion = stateVersion;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "elcungem";
  networking.wireless.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowPing = false;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    trustedInterfaces = [
      "tailscale0"
    ];
    interfaces = {
      cni0 = {
        allowedTCPPorts = [
          6443 # kubelet stuff
          10250 # metrics server
        ];
      };
    };
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      AllowUsers = [ "elia" ];
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
  services.tailscale.enable = true;
  time.timeZone = "Europe/Rome";

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--write-kubeconfig-mode=640"
      "--write-kubeconfig-group=k3s"
    ];
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "it";
  };
}
