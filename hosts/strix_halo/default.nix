{
  pkgs,
  lib,
  sys_dir,
  ...
}:
let
  username = "elia";
  eth = "eno1";
  modelsDir = "/var/lib/halogen-models";
  llamaModelsDir = "/var/lib/llama-models";
  checkpoint = "${modelsDir}/qwen38-flash-next-w4b.hgn";
  comfyDataDir = "/var/lib/comfyui";

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

  # Native ROCm from nixpkgs (ROCm 7.2.3; the hip arch list ships gfx1151, so no
  # HSA override tricks are needed on Strix Halo). llama.cpp runs from there.
  #
  # ComfyUI deliberately stays on podman. Every nix-native route ends in a
  # from-source ROCm torch build, and nixpkgs 26.11's torch 2.13 does not even
  # compile against its own aotriton headers:
  #   aotriton_adapter.h:143: use of undeclared identifier 'cookie'
  #   mha_all_aot.hip:487: no member named 'StridedVarlen' ... 'strided_varlen'
  # The prebuilt TheRock ROCm 10 wheels (nix-strix-halo) skip the compile but set
  # dontPatchELF/dontAutoPatchelf on purpose: their runtime contract is an
  # exported LD_LIBRARY_PATH over ~10 SDK directories, which the nixpkgs
  # python-env + wrapper model does not carry (`import torch` dies on
  # "libgomp.so.1: cannot open shared object file"). The container works, so the
  # image stays.

  # One holder per unit, deliberately: the unit name is baked into the script, so
  # a holder can only ever touch the unit it was built for. One generic
  # `holder <unit>` would take whatever unit name the config happened to pass it.
  #
  # The holder blocks in the foreground for as long as the model is wanted and
  # stops the unit on the way out. `exec tail -f /dev/null` will NOT do: llama-swap
  # setpgid()s every command and SIGTERMs the whole process group on unload
  # (internal/process/runtime_unix.go), so a trap in this shell is the only thing
  # that reliably runs -- and exec would replace the shell and leave the unit
  # loaded forever.
  #
  # It returns the executable, NOT the package. Interpolating a package into a
  # string yields its $out *directory*, and llama-swap then does fork/exec on that
  # directory:
  #   failed to start command '/nix/store/…-llama-swap-holder-llama-cpp.service':
  #   fork/exec …: permission denied
  # (measured on this host -- the real binary is $out/bin/llama-swap-holder-<unit>).
  swapUnitHolder =
    unit:
    let
      pkg = pkgs.writeShellApplication {
        name = "llama-swap-holder-${unit}";
        # No sudo. llama-swap.service runs as root (User= is unset) and its sandbox
        # makes sudo impossible anyway: RestrictSUIDSGID=yes and
        # SystemCallFilter=~@privileged (denied as EPERM) leave no setuid transition
        # available. Measured on the host:
        #   sudo[11947]: root : unable to open /etc/sudoers : Operation not permitted
        # systemctl needs no escalation here, only the bus, which a confined root
        # service keeps (AF_UNIX is in RestrictAddressFamilies).
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          stopped=0
          trap 'stopped=1' TERM INT

          systemctl start ${unit}
          # `wait` wakes on the group signal, which is what lets the trap take
          # effect; sleeping in the foreground would stall teardown.
          while [ $stopped -eq 0 ]; do
            sleep 3600 &
            wait $! || true
          done
          systemctl stop ${unit}
        '';
      };
    in
    "${pkg}/bin/llama-swap-holder-${unit}";
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

  environment.systemPackages = [ pkgs.python313Packages.huggingface-hub ];

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
        # llama-swap is the only model-serving port. 8731 (halogen) is closed:
        # it is reached through llama-swap now. 8188 stays open on purpose --
        # ComfyUI's web UI and `comfy-gen --server` talk to it directly, but the
        # service itself is still only started/stopped by llama-swap.
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
    "d ${comfyDataDir} 0755 root users -"
    "d ${comfyDataDir}/custom_nodes 0775 ${username} users -"
    "d ${comfyDataDir}/models 0775 ${username} users -"
    "d ${comfyDataDir}/input 0775 ${username} users -"
    "d ${comfyDataDir}/output 0775 ${username} users -"
    "d ${comfyDataDir}/temp 0775 ${username} users -"
    "d ${comfyDataDir}/user 0775 ${username} users -"
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

      # ROCm 10 image is built out-of-band from ./containers/comfyui.Containerfile
      # (no ROCm 10 in nixpkgs). Build it on the host before switching:
      #   podman build -t localhost/comfyui-rocm:rocm10 -f containers/comfyui.Containerfile .
      containers.comfyui = {
        image = "localhost/comfyui-rocm:rocm10";
        pull = "never";
        autoStart = false;
        ports = [ "8188:8188" ];
        volumes = [ "${comfyDataDir}:/data" ];
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
  # Native ROCm inference (llama.cpp only; ComfyUI stays a podman container)
  #
  # The unit exists but is NOT wantedBy multi-user.target, which mirrors the old
  # `autoStart = false`: nothing grabs the GPU until something starts it.
  # Inference is meant to be driven through llama-swap (see below), not by
  # enabling this.
  # ---------------------------------------------------------------------------

  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-rocm;
    settings = {
      # config.ini holds absolute host paths, so the same file the container read
      # works verbatim here (router mode: one process, every preset selectable by
      # the requested model name).
      models-preset = "${llamaModelsDir}/config.ini";
      host = "127.0.0.1";
      # llama-swap owns 11434 now; the router answers on a loopback-only port and
      # is reached through it.
      port = 11435;
    };
  };

  # DynamicUser cannot read ${llamaModelsDir} (0750 elia:users); run as elia,
  # who is in `render`/`video` and already gets unlimited memlock.
  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = username;
      Group = "users";
      LimitMEMLOCK = "infinity";
    };
  };

  # -------------------------------------------------------------------------
  # llama-swap: the only serving path
  #
  # One OpenAI-compatible entry point on 11434, owning the GPU schedule through
  # two exclusive groups, so text/image inference and the 124 GB halogen
  # checkpoint can never be resident at the same time on this unified-memory box:
  #
  #   halogen  swap=true   exclusive=true   -> [halogen]
  #   genai    swap=false  exclusive=true   -> [llamacpp, comfyui]
  #
  # exclusive=true is the point: a request for a member of either group unloads
  # every model of the *other* group. genai uses swap=false because the llama.cpp
  # router and ComfyUI are meant to run together inside the group.
  #
  # Backend lifecycles stay systemd's job -- llama-swap toggles the units and
  # health-checks their loopback ports. That keeps halogen's container isolation
  # (including the nftables egress lockdown below) and ComfyUI's dedicated user
  # intact, instead of flattening all three into llama-swap's own process tree.
  # -------------------------------------------------------------------------

  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
  };
  users.groups.llama-swap = { };

  # No sudoers rules for the holders. They talk to systemd directly as the (root)
  # user llama-swap already runs as -- see the swapUnitHolder comment for why sudo
  # cannot work under ProtectSystem=strict + RestrictSUIDSGID +
  # SystemCallFilter=~@privileged in the first place.

  services.llama-swap = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 11434;

    settings = {
      # 120 s default is nowhere near enough for a 124 GB halogen checkpoint or a
      # cold ComfyUI import.
      healthCheckTimeout = 900;
      logLevel = "info";
      # advertise the aliases, otherwise the preset names are invisible to clients
      # until the router happens to be loaded.
      includeAliasesInList = true;

      models = {
        "halogen" = {
          name = "halogen-qwen3.8-flash-next";
          cmd = swapUnitHolder "podman-halogen.service";
          proxy = "http://127.0.0.1:8731";
          checkEndpoint = "/health";
          aliases = [ "halogen-qwen3.8-flash-next" ];
        };

        "llamacpp" = {
          name = "llama.cpp router (all presets)";
          cmd = swapUnitHolder "llama-cpp.service";
          proxy = "http://127.0.0.1:11435";
          checkEndpoint = "/health";
          # Router mode: llama-server selects the preset from the requested model
          # name, and llama-swap forwards the body untouched (only an explicit
          # `useModelName` rewrites it). So these aliases are literally the
          # [sections] in ${llamaModelsDir}/config.ini.
          aliases = [
            "qwen3.6"
            "glm-4.5-air"
            "ori"
            "deepseek-ocr"
            "ornith-1.5-35b"
          ];
        };

        "comfyui" = {
          name = "ComfyUI";
          cmd = swapUnitHolder "podman-comfyui.service";
          proxy = "http://127.0.0.1:8188";
          # ComfyUI 0.34.1 has no /health; /system_stats answers 200 once the
          # server is up.
          checkEndpoint = "/system_stats";
        };
      };

      routing.router = {
        use = "group";
        settings.groups = {
          halogen = {
            swap = true;
            exclusive = true;
            members = [ "halogen" ];
          };
          genai = {
            # all members may run at once
            swap = false;
            exclusive = true;
            members = [ "llamacpp" "comfyui" ];
          };
        };
      };
    };
  };

  # Settings the holder needs from the llama-swap unit. The upstream module's
  # defaults break a service that drives systemd on the host:
  #   * DynamicUser  -> the uid changes every boot (and is not root), so it
  #                     cannot start/stop other units at all
  #   * PrivateUsers -> "root" inside a user namespace cannot drive host systemd
  # The rest of the module's hardening is left alone; note that this is what keeps
  # the service root, which is why the holders need no sudo.
  systemd.services.llama-swap.serviceConfig = {
    DynamicUser = lib.mkForce false;
    NoNewPrivileges = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
    CapabilityBoundingSet = lib.mkForce [
      "CAP_SETUID"
      "CAP_SETGID"
      "CAP_SETPCAP"
      "CAP_DAC_OVERRIDE"
      "CAP_READ_SEARCH"
    ];
    # llama-server / torch inherit this through the holder.
    LimitMEMLOCK = "infinity";
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
  systemd.services.llama-cpp.unitConfig.ConditionFileNotEmpty = "${llamaModelsDir}/config.ini";
}
