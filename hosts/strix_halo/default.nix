{
  pkgs,
  lib,
  inputs,
  sys_dir,
  ...
}:
let
  username = "elia";
  eth = "eno1";
  llamaModelsDir = "/var/lib/llama-models";
  comfyDataDir = "/var/lib/comfyui";

  # gufo replaces halogen as this agent's backend. Models live in their own tree;
  # the files come from the pinned `hf download`s documented in
  # modules/pi-coding-agent (gufo docs qualify exact revisions, not "latest").
  gufoModelsDir = "/var/lib/gufo-models";
  flashNextDir = "${gufoModelsDir}/qwen3.8-flash-next";
  # The loader discovers the remaining shards from the first one it is given.
  flashNextShard1 = "${flashNextDir}/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
  flashNextMtp = "${flashNextDir}/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf";
  qImageDir = "${gufoModelsDir}/qwen-image-2.1";
  gufo = inputs.gufo.packages.x86_64-linux.default;
  gufoServedName = "qwen3.8-flash-next";
  gufoCacheDir = "/var/lib/gufo/cache";

  # halogen -- the container that served this agent before gufo -- is off the
  # config entirely: no unit, no podman bridge, no egress table, no pi provider.
  # Its 126 GB of weights stay at /var/lib/halogen-models on purpose as a
  # manual-rescue fallback, and nothing starts them any more (there was never a
  # .path unit; every halogen start on 2026-09-27 was a human). To bring it back:
  #
  #   systemctl stop gufo-llm.service          # they cannot coexist, see below
  #   podman run --rm -d --name halogen -p 127.0.0.1:8731:8731 \
  #     --device=/dev/kfd --device=/dev/dri --ipc=host \
  #     --security-opt seccomp=unconfined --ulimit memlock=-1:-1 \
  #     -v /var/lib/halogen-models:/models:ro \
  #     -e HALOGEN_VISION_TOWER=1 ghcr.io/peonist-ai/halogen-flash-server:0.11.4
  #
  # Two guarantees do NOT hold when you do that. It runs with no egress lockdown
  # (the halogen0 bridge and its nftables table went away with it), and it cannot
  # share the box with gufo: flash_serve held ~70 GiB while gufo needed ~98 GiB,
  # which is what killed gufo on `hipMalloc failed for blk.8.ffn_down_exps.weight`.

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
  swapUnitHolder =
    unit:
    let
      pkg = pkgs.writeShellApplication {
        name = "llama-swap-holder-${unit}";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          stopped=0
          trap 'stopped=1' TERM INT

          # No sudo. llama-swap.service runs as root (User= is unset), and its
          # sandbox makes sudo impossible anyway: RestrictSUIDSGID=yes and
          # SystemCallFilter=~@privileged with SystemCallErrorNumber=EPERM kill any
          # setuid transition. Measured on the host during the first cutover:
          #   sudo[11947]: root : unable to open /etc/sudoers : Operation not permitted
          # systemctl only needs the bus, which a confined root service still has.
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
    # Return the executable, NOT the package. Interpolating the package yields the
    # $out *directory*, and llama-swap then does fork/exec on a directory:
    #   failed to start command '/nix/store/…-llama-swap-holder-gufo-llm.service':
    #   fork/exec …: permission denied
    # (measured on the host: that store path is a directory whose real binary is
    # $out/bin/llama-swap-holder-<unit>).
    "${pkg}/bin/llama-swap-holder-${unit}";

  # No sudoers rules: the holders talk to systemd directly as the (root) user
  # llama-swap already runs as. See the note in swapUnitHolder for why sudo is
  # unavailable inside that unit's sandbox.

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
        # llama-swap is the only model-serving port. 8731 is closed for good now
        # that halogen is off the config; gufo answers on 8732 behind the swap.
        # 8188 stays open on purpose --
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
    "d ${llamaModelsDir} 0750 ${username} users -"
    "d ${comfyDataDir} 0755 root users -"
    "d ${comfyDataDir}/custom_nodes 0775 ${username} users -"
    "d ${comfyDataDir}/models 0775 ${username} users -"
    "d ${comfyDataDir}/input 0775 ${username} users -"
    "d ${comfyDataDir}/output 0775 ${username} users -"
    "d ${comfyDataDir}/temp 0775 ${username} users -"
    "d ${comfyDataDir}/user 0775 ${username} users -"
    "d ${gufoModelsDir} 0755 ${username} users -"
    "d /var/lib/gufo 0750 gufo gufo -"
    "d ${gufoCacheDir} 0750 gufo gufo -"
  ];

  virtualisation = {
    podman.enable = true;
    oci-containers = {
      backend = "podman";

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
  # two exclusive groups on a 124 GiB unified-memory box:
  #
  #   agent    swap=true   exclusive=true   -> [qwen3.8-flash-next]        (this agent)
  #   genai    swap=false  exclusive=true   -> [6 llama.cpp presets, comfyui, Qwen-Image-2.1]
  #
  # exclusive=true is the point: a request for a member of either group unloads
  # every model of the *other* group. genai uses swap=false because its members
  # are meant to run together -- which is also the sharp edge: gufo's
  # Qwen-Image-2.1 pipeline is ~31 GiB and llama.cpp's bigger presets are not
  # small, so an image request next to a loaded 70B preset plus ComfyUI can walk
  # past the 124 GiB the box actually has. Exclusivity only protects the agent.
  #
  # Backend lifecycles stay systemd's job -- llama-swap toggles the units and
  # health-checks their loopback ports. That keeps ComfyUI's container isolation
  # and gufo's dedicated user intact, instead of flattening every backend into
  # llama-swap's own process tree.
  # -------------------------------------------------------------------------

  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
  };
  users.groups.llama-swap = { };

  # Exactly the invocations the holders can make -- none via sudo. See the
  # swapUnitHolder comment; sudo cannot work under ProtectSystem=strict +
  # RestrictSUIDSGID + SystemCallFilter=~@privileged, and the holders do not need
  # it because llama-swap is already root.

  services.llama-swap = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 11434;

    settings = {
      # 120 s default is nowhere near enough: gufo measured 61 s to load 107 GiB,
      # 45 s of which is fingerprinting 1224 tensors, and a cold ComfyUI import is
      # slower still.
      healthCheckTimeout = 900;
      logLevel = "info";

      # One entry per requestable name; no aliases anywhere.
      #
      # /v1/models lists *requestable ids*, not backends, and an alias row is a
      # copy of its parent with only the id swapped out (internal/server/api.go):
      # an alias has no name of its own, so N aliases of one model render as N
      # identical rows in Open WebUI. Making each name a real entry gives it its
      # own display name, and includeAliasesInList (default false) has nothing
      # left to duplicate -- the list is one clean row per model.
      #
      # The IDs are what the upstreams match, not labels: llama-swap forwards the
      # request body untouched, so an ID must be a llama.cpp router preset (a
      # [section] in ${llamaModelsDir}/config.ini) or gufo's --served-model-name.
      # Display names carry no backend prefix; ids are already unique across all
      # models, so nothing here can collide.
      models =
        let
          # All llama.cpp presets are ONE llama-server in router mode: one holder,
          # one port. The sharp edge that comes with sharing it -- the holder's
          # teardown is `systemctl stop llama-cpp.service`, so stopping any single
          # row here (llama-swap UI, /api/models/<id>/stop) drops the router for
          # the other five. Nothing else unloads them: genai is swap=false and
          # there is no TTL, so in practice they go only when the agent group
          # takes the GPU.
          preset = name: {
            inherit name;
            cmd = swapUnitHolder "llama-cpp.service";
            proxy = "http://127.0.0.1:11435";
            checkEndpoint = "/health";
          };
        in
        {
          "${gufoServedName}" = {
            name = "Qwen3.8 Flash-Next";
            cmd = swapUnitHolder "gufo-llm.service";
            proxy = "http://127.0.0.1:8732";
            checkEndpoint = "/health";
          };

          "qwen3.6" = preset "Qwen3.6";
          "glm-4.5-air" = preset "GLM-4.5-Air";
          "ori" = preset "Ori";
          "deepseek-ocr" = preset "DeepSeek-OCR";
          "ornith-1.5-35b" = preset "Ornith-1.5-35B";
          "ornith-og" = preset "Ornith-OG";

          "comfyui" = {
            name = "ComfyUI";
            cmd = swapUnitHolder "podman-comfyui.service";
            proxy = "http://127.0.0.1:8188";
            # ComfyUI 0.34.1 has no /health; /system_stats answers 200 once the
            # server is up.
            checkEndpoint = "/system_stats";
          };

          # ID is the gufo-image unit's --served-model-name, same passthrough rule.
          "Qwen-Image-2.1" = {
            name = "Qwen-Image-2.1";
            cmd = swapUnitHolder "gufo-image.service";
            proxy = "http://127.0.0.1:8189";
            checkEndpoint = "/health";
          };
        };

      routing.router = {
        use = "group";
        settings.groups = {
          agent = {
            swap = true;
            exclusive = true;
            members = [ gufoServedName ];
          };
          genai = {
            # all members may run at once
            swap = false;
            exclusive = true;
            members = [
              "qwen3.6"
              "glm-4.5-air"
              "ori"
              "deepseek-ocr"
              "ornith-1.5-35b"
              "ornith-og"
              "comfyui"
              "Qwen-Image-2.1"
            ];
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


  # ConditionPathIsNonEmpty is only valid in [Path] units; systemd drops it here
  # ("Unknown key ... in section [Unit]"), so the service used to start with no
  # models and crash-loop on "preset file does not exist". Gate on the preset file
  # itself: llama-server aborts if it is missing, and a failed condition is a clean
  # skip instead of a start-limit-hit.
  systemd.services.llama-cpp.unitConfig.ConditionFileNotEmpty = "${llamaModelsDir}/config.ini";

  # -------------------------------------------------------------------------
  # gufo: Qwen3.8 Flash-Next (this agent's backend) and Qwen-Image-2.1
 #
  # Both units are deliberately NOT wantedBy multi-user.target: on 124 GiB of
  # unified memory a loaded model is not something you want up by accident.
  # Both are started on demand by llama-swap (see swapUnitHolder above) --
  # gufo-llm in the `agent` group, gufo-image alongside llama.cpp and ComfyUI in
  # `genai`.
  # -------------------------------------------------------------------------

  # Dedicated uid, not the interactive user: the egress lockdown below keys on
  # the uid, and blocking `elia` would block this login session too.
  users.users.gufo = {
    isSystemUser = true;
    group = "gufo";
    # /dev/kfd + /dev/dri for the GPU, `users` to read the 0750 model trees.
    extraGroups = [
      "render"
      "video"
      "users"
    ];
    home = "/var/lib/gufo";
  };
  users.groups.gufo = { };

  systemd.services.gufo-llm = {
    description = "gufo: Qwen3.8 Flash-Next + MTP (OpenAI-compatible)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # A failed allocation used to restart forever -- the host sat at NRestarts=69,
    # reading 15.2 GiB from the SSD per attempt. Three strikes in 5 minutes and
    # the unit goes to failed, so llama-swap gets an error instead of a hang.
    startLimitIntervalSec = 300;
    startLimitBurst = 3;
    unitConfig = {
      # A missing checkpoint is a clean skip, not a crash loop.
      ConditionPathExists = [
        flashNextShard1
        flashNextMtp
      ];
    };
    serviceConfig = {
      Type = "simple";
      User = "gufo";
      Group = "gufo";
      ExecStart = ''
        ${gufo}/bin/gufo serve llm \
          --host 127.0.0.1 --port 8732 \
          --model ${flashNextShard1} \
          --speculative mtp --mtp-model ${flashNextMtp} \
          --served-model-name ${gufoServedName} \
          --sessions 2 \
          --cache-disk ${gufoCacheDir} \
          --cache-disk-staging-bytes 8589934592
      '';
      # gufo drains in-flight requests and queued disk writes on SIGTERM.
      KillSignal = "SIGTERM";
      TimeoutStopSec = 120;
      Restart = "on-failure";
      RestartSec = 5;
      LimitMEMLOCK = "infinity";
      NoNewPrivileges = true;
      PrivateTmp = true;
      # A server may answer, never call home. Cgroup-scoped (systemd's IPFilter)
      # rather than uid-keyed, so it survives uid changes. Both units bind to
      # loopback, so anything leaving this cgroup towards a non-loopback address
      # is unexpected. (systemd's IPFilter beats an nftables `meta skuid` rule
      # here -- config.users.users.gufo.uid is null at eval time for an
      # dynamically allocated id, which silently renders the nft rule empty.)
      IPAddressAllow = [
        "127.0.0.0/8"
        "::1/128"
      ];
      IPAddressDeny = "any";
    };
    wantedBy = [ ];
  };

  systemd.services.gufo-image = {
    description = "gufo: Qwen-Image-2.1 (OpenAI Images-compatible)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    startLimitIntervalSec = 300;
    startLimitBurst = 3;
    unitConfig.ConditionPathExists = "${qImageDir}/model_index.json";
    serviceConfig = {
      Type = "simple";
      User = "gufo";
      Group = "gufo";
      ExecStart = ''
        ${gufo}/bin/gufo serve image \
          --host 127.0.0.1 --port 8189 \
          --model ${qImageDir} \
          --served-model-name Qwen-Image-2.1
      '';
      KillSignal = "SIGTERM";
      TimeoutStopSec = 120;
      Restart = "on-failure";
      RestartSec = 5;
      LimitMEMLOCK = "infinity";
      NoNewPrivileges = true;
      PrivateTmp = true;
      IPAddressAllow = [
        "127.0.0.0/8"
        "::1/128"
      ];
      IPAddressDeny = "any";
    };
    wantedBy = [ ];
  };
}
