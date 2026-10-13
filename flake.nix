{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    catppuccin.url = "github:catppuccin/nix";
    nixgl.url = "github:nix-community/nixGL";
    # AI workloads (Open WebUI deploy + canonical ComfyUI workflow). Referenced
    # by modules/comfy-gen to share one workflow source with the myai repo.
    myai.url = "github:cunialino/myai";
    # llama.cpp upstream master. Only for the /v1/systemone decision endpoint, which
    # merged on 2026-10-02 (PR #29818, merge commit a4cb4c6) while nixpkgs still
    # packages 0.5.0 = upstream 7fe450e of 2026-09-23. flake = false because we want
    # the source tree, not llama.cpp's own flake graph; the overlay in
    # hosts/strix_halo turns it into the llama-cpp (and therefore llama-cpp-rocm)
    # of this system. `nix flake update llama-cpp` moves it; drop the input and the
    # overlay and the box is back on nixpkgs' build.
    llama-cpp = {
      url = "github:ggml-org/llama.cpp/master";
      flake = false;
    };
    # gufo: Strix Halo inference engine (Qwen3.8 Flash-Next + Qwen-Image-2.1).
    # Replaces halogen as this agent's backend. Only ONE derivation builds -- every
    # ROCm dependency it needs is already on cache.nixos.org -- so it does not put
    # a torch-shaped compile between us and a working system.
    gufo.url = "github:gufo-org/gufo";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      catppuccin,
      nixgl,
      home-manager,
      myai,
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
              inherit myai;
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
                  inherit catppuccin myai;
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
