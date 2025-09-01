{
  description = "Profile‑install flake for WSL2, using a modules registry";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let

      hostDir = ./hosts;
      dirEntries = builtins.readDir hostDir;
      allHosts = builtins.filter (name: dirEntries.${name} == "directory") (
        builtins.attrNames dirEntries
      );

      modules = import ./modules;

      hostProfiles = builtins.listToAttrs (
        map (
          hostName:
          let
            hostPath = hostDir + "/${hostName}/default.nix";
            host = import hostPath {};
            system = if host ? system then host.system else "x86_64-linux";

            pkgs = import nixpkgs { inherit system; };
            mods = modules { inherit pkgs; };

            allPkgs = builtins.concatLists (
              builtins.map (
                modName:
                if mods ? ${modName} then
                  mods.${modName}.packages
                else
                  throw "Module '${modName}' not found in modules/default.nix"
              ) host.enabledModules
            );
            env = pkgs.buildEnv {
              name = hostName;
              paths = allPkgs;
            };
          in
          {
            name = hostName;
            value = { inherit system env; };
          }
        ) allHosts
      );

    in
    {
      packages = builtins.foldl' (
        acc: name:
        let
          system = hostProfiles.${name}.system;
          env = hostProfiles.${name}.env;
          old = acc.${system} or { };
        in
        acc
        // {
          ${system} = old // {
            ${name} = env;
          };
        }
      ) { } (builtins.attrNames hostProfiles);
    };
}
