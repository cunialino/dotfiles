{
  pkgs,
  lib,
  config,
  sys_dir,
  ...
}:
let
  username = "elia";
  eth = "eno1";
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
        role = "agent";
      };
    };
    home-manager.users.${username} = (import ./home.nix);

    programs.dconf.enable = true;

    programs.bash.interactiveShellInit = ''
      if ! [ "$TERM" = "dumb" ]; then
        exec nu
      fi
    '';

    users.users.${username} = {
      shell = pkgs.nushell;
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQClmGcdVOIKxGE09mbmqc/RpLgfGnuWIM8jd8ShoSQyFDBnpiorURYOjs14aGw1hp0KPX0jYdN6fd/xoYdCCC0e2GshJnwlkN1OjXfMTjzIqWNa7oSoL6lhBSp22Aq+pY2kk7gL1j8q4WUTBNUcDPQVmnQdZGmhXgNSSNX6RChkEKhmAKtgLsO6FAZL4JcU4uG1o7HGtn9FN2DmYje/J9Q+WFgyYhz03TzCiyLmwsgYuM3lSwT999TztQ8tQtrVyrJcLpuA4gN0KrHidvWGit25m/bR/FD0lcHKkaxkKhBreaBYWzOKA7H8cZr9qdW9zjv9cnadXV92aQde5XZN6tXgf+N3jys2VIXLKkkKFVZ3IuHm6ZLsgY74lCzXmXDFpdzY3zR2qibqyubEBTHnXb04yb3Tgyl13RT/Vq8Sa8c+z2L8eu5o3BeyGu2acYFnn7u+AtSR4HNU5Pi1DPL8k65Us440ywurYfXwZ8qGknNNydEbZDXR+hcDK8RiTWohaWcy9L5jiRpSbgacEAHbm2Nl9BUx6muvjKiOFwhdbw3QBThCqNmSO6JcTLmIZt/uutw2vBwCKTs6i/jImVjPUIIe3vbFviCIsW4MENJglOZbvvfLGZsVXzWF/Wdmv5VAybsoom8iIKhwgZlwsJDzjRl3Yo4QB6ZA3225/p7o/fIsAw== elia.cunial@gmail.com"
      ];
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.wireless.enable = true;

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      interfaces.${eth}.allowedTCPPorts = [ 22 ];
    };

    networking.interfaces = {
      ${eth} = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.0.5";
            prefixLength = 24;
          }
        ];
      };
    };
    nix.settings.trusted-users = [ "elia" ];
  };

}
