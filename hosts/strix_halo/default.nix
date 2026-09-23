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

  # halogen gets its own podman bridge so the egress lockdown below singles it out
  # without touching llama-cpp/comfyui, which still need egress to fetch models.
  #
  # NB: podman does NOT name the bridge after the network. A network called
  # "halogen0" silently gets bridge "podmanN" (measured: name=halogen0 ->
  # network_interface=podman2). Two consequences, both handled:
  #   * --interface-name pins the bridge to ${halogenNet};
  #   * the nft rules key on the SOURCE SUBNET, not iifname, so if the device
  #     name ever drifts the block fails *closed* instead of silently opening up
  #     (that is exactly how the first version of this file leaked).
  halogenNet = "halogen0";
  halogenSubnet = "10.98.0.0/24";
  lan = "192.168.0.0/24";
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
        networks = [ halogenNet ];
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

  # ---------------------------------------------------------------------------
  # Halogen egress lockdown
  #
  # halogen is a server: it must only ever answer requests that arrived from the
  # LAN, never open a connection of its own (no telemetry, no model pulls, no
  # call-home). Its packets are *routed* by the host (podman bridge -> eno1), so
  # the block belongs in the forward hook, not in INPUT.
  # ---------------------------------------------------------------------------

  # The bridge has to exist before the container starts, and there is no
  # oci-containers option to declare one, so: idempotent oneshot.
  systemd.services.podman-network-halogen = {
    description = "Isolated podman network for halogen";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "podman-halogen.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "halogen-net" ''
        set -euo pipefail
        ${pkgs.podman}/bin/podman network exists ${halogenNet} || \
          ${pkgs.podman}/bin/podman network create --driver bridge --subnet ${halogenSubnet} \
            --interface-name ${halogenNet} --disable-dns ${halogenNet}
      '';
    };
  };

  # DNS is cut too: halogen gets no resolver at all, on-bridge or otherwise.
  #
  # --disable-dns is the part that actually matters here. With dns enabled,
  # netavark installs a hijack rule (`--dport 53 --to-destination <gateway>`) that
  # redirects EVERY port-53 packet to aardvark-dns no matter which resolver the
  # container targeted. So `tcp 8.8.8.8 53` reports OPEN while really handshaking
  # with the local resolver, which then answers NXDOMAIN for anything that is not a
  # container name. --disable-dns means no aardvark and no redirect: port 53 then
  # dies in the forward chain like everything else. The nftables rules below are
  # belt-and-braces on top of that.
  #
  # NOTE: `podman network exists || create` is idempotent, so it will NOT re-create
  # a network that already exists. After changing these flags, once by hand:
  #   systemctl stop podman-halogen && podman network rm halogen0 && systemctl restart podman-network-halogen
  #
  # Also: the `tcp HOST PORT` helper times out on getaddrinfo *and* connect together,
  # so "deb.debian.org FILTERED" usually just means "could not resolve the name".
  # Probe with literal IPs to tell a cut resolver apart from a cut path.

  networking.nftables.tables.halogen_egress = {
    family = "inet";
    content = ''
      chain forward {
        # -50 = after conntrack confirms the packet (-200) but before netavark's
        # and NixOS' own filter chains (priority 0), so nothing can ACCEPT it
        # behind our back. policy accept leaves every other flow untouched.
        type filter hook forward priority -50; policy accept;

        # The only thing allowed out: answers to LAN hosts that asked first
        # (original direction is ${lan} -> halogen).
        ip saddr ${halogenSubnet} ip daddr ${lan} ct state established,related accept

        # Everything else is gone: no internet, no poking at LAN hosts that never
        # called it, no IPv6 either. This also kills any hard-coded external
        # resolver (8.8.8.8 & friends).
        ip saddr ${halogenSubnet} limit rate 10/minute burst 20 packets log prefix "halogen-egress-drop: " drop
        ip saddr ${halogenSubnet} counter drop
      }

      chain input {
        # Belt and braces on top of --disable-dns: if a resolver ever ends up back
        # on this bridge, halogen still cannot reach it.
        type filter hook input priority -50; policy accept;

        ip saddr ${halogenSubnet} meta l4proto { tcp, udp } th dport 53 limit rate 10/minute burst 20 packets log prefix "halogen-dns-drop: "
        ip saddr ${halogenSubnet} meta l4proto { tcp, udp } th dport 53 counter reject with icmpx type port-unreachable
      }
    '';
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
