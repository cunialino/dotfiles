{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    catppuccin.url = "github:catppuccin/nix";
    nixgl.url = "github:nix-community/nixGL";
    # AI workloads (Open WebUI deploy + canonical ComfyUI workflow). Referenced
    # by modules/comfy-gen to share one workflow source with the myai repo.
    myai.url = "github:cunialino/myai";
    # llama.cpp upstream master. Was the only way to get /v1/systemone (merged
    # 2026-10-02, PR #29818) while nixpkgs pinned 0.5.0; nixpkgs is at 0.7.0 now and
    # ships that endpoint, so this input is no longer load-bearing -- see the overlay
    # in hosts/strix_halo, which is where it becomes the llama-cpp (and therefore
    # llama-cpp-rocm) of this system. `nix flake update llama-cpp` moves it; setting
    # llamaCppMain = false puts the box back on nixpkgs' build.
    # flake = false because we want the source tree, not llama.cpp's own flake graph.
    llama-cpp = {
      url = "github:ggml-org/llama.cpp/master";
      flake = false;
    };
    # ROCm 10.1 for llama.cpp's HIP build. nixpkgs is still on 7.2.4 and the 10.1
    # set lives only on the closed, unmerged PR #573885, which gufo carries as this
    # fork: it adds rocmPackages_10 beside rocmPackages, plus per-arch scopes so
    # rocblas/hipblaslt build once per gfx target instead of sixteen arches at once.
    # Pinned to the rev gufo itself resolves to -- same narHash, so no extra download
    # and the gfx1151 ROCm closure stays the store paths this box already holds --
    # and deliberately not follows = "gufo/nixpkgs-rocm10", because gufo.cachix.org
    # is not in nix.settings and an afternoon of Tensile should not ride along with a
    # `nix flake update gufo`. See llamaCppRocm10 in hosts/strix_halo.
    nixpkgs-rocm10.url = "github:gufo-org/nixpkgs/1a6ba8bc6f744f7a843d025e46bc9911b4b6c37d";
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
