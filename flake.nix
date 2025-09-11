{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    let
      hosts = {
        gem = {
          system = "x86_64-linux";
          file = ./hosts/gem.nix;
        };
      };

      mod_dir = ./modules;

      mkHostAttr =
        name:
        { system, file }:
        {
          name = name;
          value = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.${system};
            modules = [ (mod_dir + "/common") file ];
            extraSpecialArgs = {
              modulesPath = mod_dir;
            };
          };
        };
    in
    {
      homeConfigurations = builtins.listToAttrs (
        map (name: mkHostAttr name hosts.${name}) (builtins.attrNames hosts)
      );
    };
}
