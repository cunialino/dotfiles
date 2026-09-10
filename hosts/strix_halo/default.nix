{
  pkgs,
  sys_dir,
  ...
}:
let
  username = "elia";
  eth = "eno1";
  modelsDir = "/var/lib/halogen-models";
  llamaModelsDir = "/var/lib/llama-models";
  checkpoint = "${modelsDir}/qwen38-flash-next-w4b.hgn";
in
{
  imports = [
    ./hardware-config.nix
    sys_dir
  ];

  home-manager.users.${username} = import ./home.nix;

  users.users.${username} = {
    extraGroups = [
      "networkmanager"
      "render"
      "video"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPKPt5/R03Ivma94RuLK4e6vwgwiQbV/jMcvkVbpqGT elia@elcungem"
    ];
  };

  environment.systemPackages = [
    pkgs.python313Packages.huggingface-hub
  ];

  boot.kernelParams = [
    "amd_iommu=off" # 13-16% prefill, kills NPU, only on dedicated box
    "amdgpu.gttsize=126976"
    "amdgpu.vm_update_mode=0"
    "amdgpu.noretry=0"
    "amdgpu.sg_display=0"
  ];
  boot.extraModprobeConfig = ''
    options ttm pages_limit=32505856
  '';
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware = {
    amdgpu.initrd.enable = true;
    enableRedistributableFirmware = true;
    graphics.enable = true;
  };

  networking = {
    networkmanager.enable = false;
    nftables.enable = true;
    wireless.enable = true;
    firewall = {
      enable = true;
      interfaces.${eth}.allowedTCPPorts = [
        22
        8731
        11434
        8188
      ];
    };
    interfaces = {
      ${eth} = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.0.6";
            prefixLength = 24;
          }
        ];
      };

    };
  };
  nix.settings.trusted-users = [ username ];

  systemd.tmpfiles.rules = [
    "d ${modelsDir} 0750 ${username} users -"
    "d ${llamaModelsDir} 0750 ${username} users -"
    "d /var/lib/comfyui 0755 root users -"
    "d /var/lib/comfyui/custom_nodes 0775 ${username} users -"
    "d /var/lib/comfyui/models 0775 ${username} users -"
    "d /var/lib/comfyui/input 0775 ${username} users -"
    "d /var/lib/comfyui/output 0775 ${username} users -"
    "d /var/lib/comfyui/temp 0775 ${username} users -"
    "d /var/lib/comfyui/user 0775 ${username} users -"

  ];

  virtualisation = {
    podman.enable = true;
    oci-containers = {
      backend = "podman";
      containers.halogen = {
        image = "ghcr.io/peonist-ai/halogen-flash-server:0.5.6";
        autoStart = true;
        ports = [ "8731:8731" ];
        volumes = [ "${modelsDir}:/models:ro" ];
        environment = {
          "HALOGEN_VISION_TOWER" = "1";
        };
        extraOptions = [
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--security-opt=seccomp=unconfined"
          "--ipc=host"
          "--ulimit=memlock=-1:-1"
          "-e"
          "HALOGEN_VISION_TOWER=1"
        ];
      };

      # ROCm 10 images are built out-of-band from ./containers/*.Containerfile
      # (no ROCm 10 in nixpkgs yet). Build them on the host before switching:
      #   podman build -t localhost/llama-cpp-rocm:rocm10 -f containers/llama-cpp.Containerfile .
      #   podman build -t localhost/comfyui-rocm:rocm10 -f containers/comfyui.Containerfile .
      containers.llama-cpp = {
        image = "localhost/llama-cpp-rocm:rocm10";
        pull = "never";
        autoStart = false;
        ports = [ "11434:11434" ];
        volumes = [ "${llamaModelsDir}:/models:ro" ];
        extraOptions = [
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--security-opt=seccomp=unconfined"
          "--ipc=host"
          "--ulimit=memlock=-1:-1"
        ];
      };

      containers.comfyui = {
        image = "localhost/comfyui-rocm:rocm10";
        pull = "never";
        autoStart = false;
        ports = [ "8188:8188" ];
        volumes = [ "/var/lib/comfyui:/data" ];
        extraOptions = [
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--security-opt=seccomp=unconfined"
          "--ipc=host"
          "--ulimit=memlock=-1:-1"
        ];
      };
    };
  };

  # Populate with: hf download peonist-ai/halogen-qwen3.8-flash-next --local-dir /var/lib/halogen-models
  # The path unit starts the container as soon as the checkpoint appears.
  systemd.services.podman-halogen.unitConfig.ConditionPathExists = checkpoint;
  systemd.services.podman-llama-cpp.unitConfig.ConditionPathIsNonEmpty = llamaModelsDir;
  systemd.paths.halogen-models = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathExists = checkpoint;
      Unit = "podman-halogen.service";
    };
  };
}
