{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    catppuccin.url = "github:catppuccin/nix";
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
      hosts_os = {
        asus-laptop = {
          system = "x86_64-linux";
          file = ./hosts/asus-laptop;
        };
        gemos = {
          system = "x86_64-linux";
          file = ./hosts/gem;
        };

      };
      hosts = {
        gem = {
          system = "x86_64-linux";
          file = ./hosts/gem.nix;
        };
        wsl2 = {
          system = "x86_64-linux";
          file = ./hosts/wsl2.nix;
        };
      };

      mod_dir = ./modules;

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
              (mod_dir + "/common")
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
          h = hosts_os.${name};
          system = h.system;
        in

        nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit inputs;
                  inherit catppuccin;
                  nixgl = nixgl;
                };
              };
            }
            (./hosts + "/${name}")
          ];

          specialArgs = {
            inherit inputs;
            inherit catppuccin;
          };
        };

    in
    {
      homeConfigurations = builtins.listToAttrs (
        map (name: mkHostAttr name hosts.${name}) (builtins.attrNames hosts)
      );
      nixosConfigurations = builtins.listToAttrs (
        map (n: {
          name = n;
          value = mkNixos n;
        }) (builtins.attrNames hosts_os)
      );
    };
}
