{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    catppuccin.url = "github:catppuccin/nix/release-25.05";
    nixgl.url = "github:nix-community/nixGL";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      catppuccin,
      nixgl,
      home-manager,
      ...
    }@inputs:
    let
      hosts = (import ./hosts);
      mod_dir = ./modules;
      sys_dir = ./sys_mods;

      mkHostAttr =
        name:
        { system, file }:
        {
          name = name;
          value = home-manager.lib.homeManagerConfiguration {

            pkgs = import nixpkgs {
              system = system;
              overlays = [
                nixgl.overlay
              ];
            };
            modules = [
              file
              catppuccin.homeModules.catppuccin
            ];
            extraSpecialArgs = {
              modulesPath = mod_dir;
              nixgl = nixgl;
            };
          };
        };

      mkNixos =
        name:
        let
          h = hosts.hosts_os.${name};
          system = h.system;
        in

        nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            { networking.hostName = h.hostname; }
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit catppuccin;
                  modulesPath = mod_dir;
                  nixgl = nixgl;
                };
              };
            }
            (h.file)
          ];

          specialArgs = {
            inherit inputs catppuccin;
            mod_dir = mod_dir;
            sys_dir = sys_dir;
          };
        };

    in
    {
      homeConfigurations = builtins.listToAttrs (
        map (name: mkHostAttr name hosts.hosts_hm.${name}) (builtins.attrNames hosts.hosts_hm)
      );
      nixosConfigurations = builtins.listToAttrs (
        map (n: {
          name = n;
          value = mkNixos n;
        }) (builtins.attrNames hosts.hosts_os)
      );
    };
}
