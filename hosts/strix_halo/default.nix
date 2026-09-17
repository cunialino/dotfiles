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
  sdModelsDir = "/var/lib/sd-models";
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
    (pkgs.writeShellScriptBin "sd-cli" ''
      # One-shot wrapper around the sd-cli-rocm image (built out-of-band from
      # containers/sd-cli.Containerfile). Models are read from ${sdModelsDir};
      # generated images land in the caller's current directory.
      TTY=()
      [ -t 1 ] && TTY=(-it)
      exec podman run --rm "''${TTY[@]}" \
        --device=/dev/kfd \
        --device=/dev/dri \
        --security-opt=seccomp=unconfined \
        --ipc=host \
        --ulimit=memlock=-1:-1 \
        -v ${sdModelsDir}:/models:ro \
        -v "$PWD:/work" \
        -w /work \
        localhost/sd-cli-rocm:rocm10 sd-cli "$@"
    '')
  ];

  # Rootless podman + ROCm needs locked memory for HSA buffer mapping.
  security.pam.loginLimits = [
    {
      domain = username;
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
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
    "d ${sdModelsDir} 0750 ${username} users -"
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
        image = "ghcr.io/peonist-ai/halogen-flash-server:0.11.4";
        autoStart = false;
        ports = [ "8731:8731" ];
        volumes = [ "${modelsDir}:/models:ro" ];
        environment = {
          "HALOGEN_VISION_TOWER" = "1";
          "HALOGEN_TEMPERATURE" = "1.0";
          "HALOGEN_TOP_P" = "0.95";
          "HALOGEN_TOP_K" = "20";
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
      #   podman build -t localhost/sd-cli-rocm:rocm10 -f containers/sd-cli.Containerfile .
      containers.llama-cpp = {
        image = "localhost/llama-cpp-rocm:rocm10";
        pull = "never";
        autoStart = false;
        ports = [ "11434:11434" ];
        # Mounted at the same absolute path as on the host: config.ini uses absolute
        # model paths, so one preset file serves both this container and a native
        # llama-server running directly on the host.
        volumes = [ "${llamaModelsDir}:${llamaModelsDir}:ro" ];
        environment = {
          # Beats the image default so the preset path always tracks llamaModelsDir.
          LLAMA_ARG_MODELS_PRESET = "${llamaModelsDir}/config.ini";
          HIP_LAUNCH_BLOCKING = "1";
        };
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

  # ConditionPathIsNonEmpty is only valid in [Path] units; systemd drops it here
  # ("Unknown key ... in section [Unit]"), so the service used to start with no
  # models and crash-loop on "preset file does not exist". Gate on the preset file
  # itself: llama-server aborts if it is missing, and a failed condition is a clean
  # skip instead of a start-limit-hit.
  systemd.services.podman-llama-cpp.unitConfig.ConditionFileNotEmpty = "${llamaModelsDir}/config.ini";
}
