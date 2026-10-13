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

  # vllm-d3-nano (vllm-sr Decision 3.0, 2.39 B) is the always-on decision model:
  # a "System One" reader that answers typed questions -- choice, noul, score --
  # in one forward pass, no generation. llama.cpp knows it natively
  # (general.architecture = qwen35, qwen35.decision.type = vllm-d3, log line
  # "decision model type: vllm-d3", /v1/models reports
  # architecture.output_modalities = ["decisions"]), so the endpoint is
  # /v1/systemone rather than chat. Weights are the official GGUF, placed by hand
  # under ${llamaModelsDir} like every other model tree here, so the command is
  # recorded:
  #
  #   hf download ggml-org/vllm-d3-nano-GGUF vllm-d3-nano-Q8_0.gguf \
  #     --local-dir /var/lib/llama-models/d3-nano
  #
  # 2552358432 bytes, sha256
  # 5da453f497bdadfa1890e914c1aa73815ad869e50711925a581c53079123328e -- the same
  # digest the HF API reports as the file's LFS oid.
  #
  # The mmproj (365 MB) is deliberately NOT on disk: the d3 family also reads
  # images and video, nothing here sends either, and the vision encoder is not in
  # this file (input_modalities stays ["text"] without a projector), so it would
  # be 365 MB of cold storage, not a capability.
  #
  # Q8_0 over BF16 (4.79 GB) for the reason that already governed Julia: the
  # answers are probabilities, and a quantised embedding is a quantised answer.
  # Julia could afford that because the file was 168 MB; nano can afford it
  # because 2.4 GiB is what fits (see the budget on the unit). Note the contrast
  # with internlm/Intern-Decision-2B, whose calibration temperature (2.1005, fitted
  # on BF16) makes quantising it a change of contract -- that model is not a
  # llama.cpp decision model either (/v1/systemone answers 501 "This model is not a
  # decision model", output_modalities ["text"]), so it needs hand-rolled logprobs
  # at the answer slot: the decider-0.8b mistake again, and why it is not here.
  # The d3 GGUF ships qwen35.decision.temperature.{choice,score,noul} = 1.0, so
  # llama.cpp applies no correction and Q8_0 is the shipping configuration.
  #
  # Chosen against this box's memory ceiling, not against the leaderboard. Of the
  # ggml-org decision collection, what fits beside a loaded gufo is d3-edge (768 MB
  # Q8_0, Jev Decision Index 0.3.2 = 20.2), Julia-1 (160 MB, not on that board),
  # d3-lite (1.03 GB, 32.3) and nano; d3-mini (4.9 GB, 52.6) and every 4B-and-up
  # entry -- Kev-4B, lev, Clef-Flash, Clef/OpenJev/vllm-d3 at 27 GB -- are not.
  # nano is the largest that still fits and the best of what does (38.9, on the
  # board's Pareto frontier, first among the twelve entries within 0.75-1.33x its
  # size).
  #
  # Julia-1 stays on disk under ${llamaModelsDir}/julia-1 as the rollback: same
  # /v1/systemone contract, 0.68 GiB instead of 3.4, answers in 24-58 ms instead of
  # 160-230 ms, and its measurements are kept in git history. Rolling back is these
  # three bindings plus -c/-b/-ub back to 8192.
  #
  # Named for the job, not the weights: the unit is llama-decision, so the next
  # swap (Clef, OpenJev, a bigger d3 on a bigger box) is again these three bindings
  # plus the flags the note on the unit documents.
  decisionId = "d3-nano";
  decisionGguf = "${llamaModelsDir}/d3-nano/vllm-d3-nano-Q8_0.gguf";
  decisionPort = 11436;

  # gufo replaces halogen as this agent's backend. Models live in their own tree;
  # the files come from the pinned `hf download`s documented in
  # modules/pi-coding-agent (gufo docs qualify exact revisions, not "latest").
  gufoModelsDir = "/var/lib/gufo-models";
  flashNextDir = "${gufoModelsDir}/qwen3.8-flash-next";
  # The loader discovers the remaining shards from the first one it is given.
  flashNextShard1 = "${flashNextDir}/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
  flashNextMtp = "${flashNextDir}/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf";
  # The image model is the LoRA'd variant, merged from the LoRA in the home dir
  # at --strength 0.8 and served to clients as plain qwen-image-2.1. The
  # untouched base tree next to it on disk is a rollback copy only: nothing in
  # this config points at it.
  qImageLrDir = "${gufoModelsDir}/qwen-image-2.1-lr";
  gufo = inputs.gufo.packages.x86_64-linux.default;
  gufoServedName = "qwen3.8-flash-next";
  gufoCacheDir = "/var/lib/gufo/cache";

  # Qwen-Image-2.1 serves the LoRA'd variant (qwen-image-2.1-lr) through the
  # `genai` group. The gate exists because image generation drops gufo's ~31 GiB
  # image pipeline into the swap=false `genai` group -- the largest single chunk
  # of the coexistence risk on a box with 124 GiB and no swap. Leave true to keep
  # the row routable, or set to false to take it offline; the gufo-image.service
  # unit stays defined and hand-startable either way.
  qwenImageEnabled = true;

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

  # llama.cpp comes from upstream master, not from nixpkgs -- see nixpkgs.overlays
  # below the `in`. Setting this to false puts the box back on nixpkgs' 0.5.0.
  llamaCppMain = true;

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

  # -------------------------------------------------------------------------
  # llama.cpp from upstream master, by overlay
  #
  # nixpkgs pins llama-cpp 0.5.0 = upstream 7fe450e (2026-09-23). The /v1/systemone
  # decision endpoint merged on 2026-10-02 (PR #29818), so the packaged build
  # cannot serve it -- the installed binary's route table stops at
  # /v1/{chat,completions,embeddings,health,messages,models,rerank,responses}.
  # An overlay on the source is cheaper here than a nixpkgs bump: the alternative
  # moves every package on the box, including the ROCm stack that the HIP build
  # and ComfyUI's container ride on.
  #
  # One entry covers both attributes: pkgs/by-name/ll/llama-cpp-rocm/package.nix is
  # literally `llama-cpp.override { rocmSupport = true; }`, and it takes llama-cpp
  # from the final package set, so the override propagates to the -rocm variant
  # that llama-cpp.service and llama-decision.service use.
  #
  # The web UI is switched off rather than maintained. nixpkgs builds tools/ui with
  # fetchNpmDeps, and that hash belongs to the packaged tag: tracking master means
  # re-hashing it on every bump, and the npm-config hook hard-fails if npmDeps is
  # simply nulled out, so the hook comes out of nativeBuildInputs too. Nothing here
  # opens the UI -- both servers bind to loopback and every client reaches them
  # through llama-swap on 11434.
  # -------------------------------------------------------------------------

  nixpkgs.overlays = lib.optionals llamaCppMain [
    (
      final: prev:
      {
        # gfx1151 only, and it has to be set here rather than on llama-cpp-rocm:
        # pkgs/by-name/ll/llama-cpp-rocm/package.nix is
        #   { llama-cpp }: llama-cpp.override { rocmSupport = true; }
        # so that wrapper takes one argument and `rocmGpuTargets` reaches the real
        # package only through this attribute.
        #
        # nixpkgs defaults to its whole ROCm list -- gfx900 through gfx1201,
        # sixteen arches -- because it publishes one binary for every AMD GPU. That
        # is free while the build comes off cache.nixos.org and ruinous for a source
        # override, where nothing is cached and every arch is its own set of HIP
        # kernels. This board has exactly one, and it is already inside nixpkgs'
        # list, so the target is unchanged and only the count is. If the box ever
        # gains a second AMD GPU, this is the line to widen.
        llama-cpp = (
          prev.llama-cpp.override { rocmGpuTargets = [ "gfx1151" ]; }
        ).overrideAttrs (
          finalAttrs: prevAttrs:
          {
            version = "main-${inputs.llama-cpp.shortRev or "unlocked"}";
            src = inputs.llama-cpp;

            npmDeps = null;
            preConfigure = "";
            nativeBuildInputs = lib.filter (
              d: lib.getName d != "npm-config-hook"
            ) (prevAttrs.nativeBuildInputs or [ ]);
            cmakeFlags = (prevAttrs.cmakeFlags or [ ]) ++ [ "-DLLAMA_BUILD_UI=OFF" ];
          }
        );

      }
    )
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
        # 11434 is llama-swap, the switchable models: 8731 is closed for good now
        # that halogen is off the config; gufo answers on 8732 behind the swap.
        # 11436 is llama-decision (d3-nano, always on) published directly because
        # llama-swap has no /v1/systemone route to proxy it -- see the unit.
        # 8188 stays open on purpose --
        # ComfyUI's web UI and `comfy-gen --server` talk to it directly, but the
        # service itself is still only started/stopped by llama-swap.
        11434
        11436
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

      # ROCm leaves the GPU busy at idle when several HW queues are in play;
      # upstream's fix is to default GPU_MAX_HW_QUEUES=1 on HIP (llama.cpp#24237).
      # Checked against the installed build (llama-cpp 0.5.0 b11146, commit
      # 7fe450e): `strings` over the binary and bin/libggml-hip.so finds no
      # GPU_MAX_HW_QUEUES at all, so that default is NOT in this build and the
      # var has to come from the unit. Set once here -- it is read by HIP at
      # context creation, so it must be in the environment of llama-server
      # itself, not of the unit's wrapper, and the router children inherit it.
      # Drop this once nixpkgs' llama-cpp-rocm carries #24237.
      Environment = [ "GPU_MAX_HW_QUEUES=1" ];
    };
  };

  # ComfyUI rides the llama.cpp router's lifecycle. Every llama.cpp preset is one
  # router unit, so hooking the container to that unit covers all of them at
  # once -- llama-swap has no "start this model alongside that one" primitive
  # (its only preload hook, hooks.on_startup, fires when llama-swap boots).
  #
  # Wants=, not Requires=: a failing ComfyUI must never take the chat presets
  # down, and `systemctl stop podman-comfyui.service` by hand must not stop the
  # router. No After= either -- ComfyUI's cold torch import runs in parallel with
  # llama-server instead of delaying it.
  systemd.services.llama-cpp.unitConfig.Wants = [ "podman-comfyui.service" ];

  # One-way stop propagation (systemd.unit(5), PartOf=): stopping or restarting
  # llama-cpp.service propagates here, never the reverse. This is what unloads
  # the container when the `agent` group takes the GPU -- llama-swap evicts the
  # llama holder, the holder stops the router unit, the container follows. Note
  # it also fires when the llama-swap UI stops any one preset row, which already
  # drops the whole shared router (see the `preset` binding below).
  systemd.services.podman-comfyui.unitConfig.PartOf = [ "llama-cpp.service" ];

  # -------------------------------------------------------------------------
  # llama-decision: the always-on System One reader (vllm-d3-nano)
  #
  # Always on means wantedBy multi-user.target: this is the one inference unit on
  # the box that comes up with the host and stays up. It costs 3.4-3.6 GiB of the
  # 124 -- 2.42 GiB of it on the device side (2.37 GiB of Q8_0 weights + 448 MiB of
  # compute buffers + 48 MiB of KV at -c 4096, which is what llama.cpp itself
  # projects), the rest host anon (HIP context, rocblas scratch, staging) -- and
  # answers in 160-230 ms on the 90-280 token states this box actually sees, so
  # unlike every other unit here it is worth paying for permanently: never having
  # to wait for a model to load is the point.
  #
  # The cost is the whole argument, so it is measured rather than assumed. With
  # gufo loaded and serving, MemAvailable has dropped to 5,823 MiB (median 10,268
  # over 604 requests), there is no swap, and the OOM killer has already taken gufo
  # twice (Oct 14 21:12, Oct 15 09:24) at the footprint that existed BEFORE this
  # unit was this big. So the rule is not "make room", it is "be sure who dies if
  # room runs out", and it is never gufo:
  #   * this unit dies first (OOMScoreAdjust=800, and the cgroup caps below); the
  #     reader going dark and reloading is a bad minute, gufo going dark is a dead
  #     agent mid-turn;
  #   * gufo is last (OOMScoreAdjust=-500) and its working set is kept out of
  #     reclaim's way with MemoryLow -- a protection, not a reservation: unlike
  #     memory.min it never refuses an allocation, it just makes this cgroup the
  #     last one the kernel takes pages from.
  # MemoryHigh/MemoryMax bound the unit's own footprint, and are set above the
  # measured cost on purpose: clamp them to 2.5 GiB and the reader does not die
  # gracefully, it thrashes its own pages and answers slowly forever. Note they are
  # not the primary guarantee -- the ~2.4 GiB llama.cpp puts on the device goes
  # through the amdgpu/TTM pool, not through the memory controller, which is exactly
  # why process RSS read 1.1 GiB while MemAvailable fell 3.4 GiB.
  #
  # Why it is NOT a llama-swap row, and answers on its own published port:
  #   * llama-swap has no /v1/systemone. The string appears 0 times in its
  #     binaries (build 249 and master alike) and POST :11434/v1/systemone is a
  #     404. A row would be a proxy that cannot forward the only endpoint worth
  #     calling;
  #   * the router is a shared unit, so a row is only ever as always-on as the
  #     biggest preset beside it: holder teardown is
  #     `systemctl stop llama-cpp.service`, and the agent group stops that holder
  #     whenever this agent gets a turn;
  #   * always-on *on the router* would mean persistent=true on a group whose
  #     member is the router itself, i.e. nothing could ever unload up to
  #     `models-max = 2` presets of 23-65 GiB -- precisely the memory gufo needs
  #     back (~98 GiB) when the agent group takes over.
  # One llama-server per unit keeps the holders honest; this one has no holder at
  # all.
  #
  # Calling it. This GGUF is a native decision model: llama.cpp logs "decision
  # model type: vllm-d3" for it and /v1/models reports
  # architecture.output_modalities = ["decisions"]. `questions` is an OBJECT keyed
  # by field id, each {type: choice|noul|score, criteria: {label: description}} --
  # an array of question objects is rejected with "\"questions\" must be a
  # non-empty object" (and criteria, not options, is the required key). So there is no generation and
  # no sampling -- one forward pass over `state` yields per question a choice
  # (softmax over the criteria labels), a noul (probability of the question being
  # true) or a score (position on the criteria scale). No --temp/--jinja/--top-p
  # here on purpose: the previous reader on this port (decider-0.8b) needed a
  # hand-rolled logprobs readout at the answer slot because llama.cpp does not
  # recognise it as a decision model at all -- its GGUF carries no *.decision.*
  # keys -- which is also why that model is gone from the config.
  #
  # Two limits of these encoder-style models, both measured here, both easy to
  # trip (the launch post's commenters hit the first one blind):
  #   * the input has to fit in ONE batch, so --ubatch-size, not --ctx-size, is
  #     the real ceiling: at -ub 2048 a 5611-token state comes back "input (5611
  #     tokens) is too large to process. increase the physical batch size (current
  #     batch size: 2048)";
  #   * per-request context is ctx/parallel -- kv_unified stays false for this
  #     class -- so -c 8192 -np 4 would cap a single state at 2048 tokens.
  # Hence -np 1 with -c = -b = -ub = 8192, one slot holding the model's entire
  # trained context; llama.cpp will not go past it anyway ("the slot context
  # (32768) exceeds the training context of the model (8192) - capping").
  # Concurrency queues instead of splitting the context, which for a ~50 ms read
  # is the right trade.
  #
  # Measured here (2026-10-17, main-1b70350, gufo resident on the same iGPU):
  #   launch -> /health 200      ~4 s, 3.44 GiB of MemAvailable
  #   275 tok, choice + noul     0.327 s cold / 0.16-0.23 s warm
  #                              (billing p=0.99991, confidence 0.9991)
  #   3607 tok                   1.65 s -> ~2.2 k tok/s of prefill
  #   MemAvailable 8.94 -> 5.34 GiB with it serving, back to 8.94 on kill
  # That is ~4x Julia-1's read time (0.024-0.058 s) for 24x the weights, which is
  # the trade being made: 16-23 readings/s still, against a queue that gufo itself
  # already holds at 20-35 s. The 13.4 ms in the d3 card is an MI325X.
  #
  # Answer quality still lives in the criteria descriptions, not in the state or
  # the parameter count: with one-word labels the same ticket flipped between
  # billing and sales on Julia, with the fuller descriptions it held billing at
  # 99.4-99.9%. Write the criteria; nano inherits that rule rather than replacing
  # it. What nano should buy is the long-label-list and knowledge cases where the
  # 144 M model said it was weak (its own card: Banking77 64/100 against a Jev
  # reference of 87/100). Re-check the workflow's own questions before trusting
  # either number.
  #
  systemd.services.llama-decision = {
    description = "llama.cpp: vllm-d3-nano decision model (always on, /v1/systemone)";
    after = [ "network.target" ];
    wants = [ "network.target" ];
    unitConfig.ConditionPathExists = decisionGguf;
    # Three strikes like gufo, so an OOM death does not reload 2.4 GB in a loop and
    # turn one bad minute into a permanent load on the same pool. These are [Unit]
    # keys -- putting them in serviceConfig would have systemd drop them ("Unknown
    # key ... in section [Service]"), the same trap this file already records for
    # ConditionPathIsNonEmpty.
    startLimitIntervalSec = 300;
    startLimitBurst = 3;
    serviceConfig = {
      Type = "simple";
      # Same reasoning as llama-cpp.service: elia is in render/video, has
      # unlimited memlock and can read ${llamaModelsDir} (0750 elia:users).
      User = username;
      Group = "users";
      ExecStart = ''
        ${pkgs.llama-cpp-rocm}/bin/llama-server \
          --host 0.0.0.0 --port ${toString decisionPort} \
          --model ${decisionGguf} \
          --alias ${decisionId} \
          --n-gpu-layers 999 \
          --ctx-size 4096 \
          --parallel 1 \
          --batch-size 4096 \
          --ubatch-size 4096 \
          --flash-attn on \
          --poll 0
      '';

      # 4096, where Julia ran at 8192. nano's n_ctx_train is 262144, so this is a
      # budget choice and not the model's ceiling -- and since -ub is the real
      # ceiling for this class (see the two limits above), it is also a choice
      # about the largest state that can be answered at all. The evidence: 2,404
      # reads served off Julia, largest 987 tokens, median 87. 4096 is 4x the
      # largest one ever seen; 8192 would cost another ~0.45 GiB of device-side
      # buffers to cover states that have not occurred. If one does occur, llama.cpp
      # says so out loud ("input (N tokens) is too large to process. increase the
      # physical batch size") rather than answering from a truncated state.
      #
      # No --sleep-idle-seconds, unlike the router's presets: releasing a 2.4 GiB
      # model to save nothing buys back a reload on the next question, and being
      # instantly answerable is the whole reason this one stays up. --poll 0 is
      # what keeps it from burning the GPU while idle (same fix as the router).
      # GPU_MAX_HW_QUEUES=1 for the reason documented on llama-cpp.service.
      Environment = [ "GPU_MAX_HW_QUEUES=1" ];

      KillSignal = "SIGTERM";
      TimeoutStopSec = 60;
      Restart = "on-failure";
      RestartSec = 5;
      LimitMEMLOCK = "infinity";
      NoNewPrivileges = true;
      PrivateTmp = true;

      # The ordering: this reader is the kernel's first candidate, gufo's last. See
      # the budget note above the unit for why OOMScoreAdjust, not memory.max, is
      # the guarantee that actually holds here.
      OOMScoreAdjust = 800;
      MemoryHigh = "4G";
      MemoryMax = "4.5G";
      # Answers, never calls home. IPFilter is on the cgroup and filters
      # INBOUND as well as outbound, so the LAN has to be in this list for a client
      # on 192.168.0.0/24 to connect at all -- the firewall is what keeps that off
      # the internet, and nothing here may initiate a connection anywhere.
      IPAddressAllow = [
        "127.0.0.0/8"
        "::1/128"
        "192.168.0.0/24"
      ];
      IPAddressDeny = "any";
    };
    wantedBy = [ "multi-user.target" ];
  };

  # -------------------------------------------------------------------------
  # llama-swap: the serving path for everything switchable
  #
  # One OpenAI-compatible entry point on 11434, owning the GPU schedule through
  # groups on a 124 GiB unified-memory box:
  #
  #   agent    swap=true   exclusive=true  -> [qwen3.8-flash-next]                  (this agent)
  #   genai    swap=false  exclusive=true  -> [7 llama.cpp presets, comfyui]
  #
  # llama-decision is not in this table: it is an always-on model on its own port,
  # because llama-swap has no /v1/systemone to route.
  #
  # exclusive=true is the point: a request for a member of either group unloads
  # every model of the *other* group. genai uses swap=false because its members
  # are meant to run together -- which is also the sharp edge: llama.cpp's bigger
  # presets are not small and a Qwen-Image generation wants its UNet plus text
  # encoder resident, so the group can still walk past the 124 GiB the box has
  # (and there is no swap). Exclusivity only protects the agent. Qwen-Image-2.1
  # (the LoRA'd qwen-image-2.1-lr variant) is the third big resident chunk here;
  # it is routable via qwenImageEnabled above.
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
          # the rest of them. Nothing else unloads them: genai is swap=false and
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
          "lk" = preset "Lk";
          "deepseek-ocr" = preset "DeepSeek-OCR";
          "ornith-1.5-35b" = preset "Ornith-1.5-35B";
          "ornith-og" = preset "Ornith-OG";

          "comfyui" = {
            name = "ComfyUI";
            cmd = swapUnitHolder "podman-comfyui.service";
            proxy = "http://127.0.0.1:8188";
            # Health-check on /system_stats: it answers 200 only once the server
            # is actually up (this backend has nothing on /health).
            checkEndpoint = "/system_stats";
          };
        }
        // lib.optionalAttrs qwenImageEnabled {
          # A row that is not in a group is not routable at all -- the group
          # router builds its process map from group membership alone
          # (router/group.go) -- so the entry disappears together with its member
          # below. ID must equal the gufo-image unit's --served-model-name: the
          # body is forwarded untouched, so this is exactly the string clients
          # send. The LoRA lives at ${qImageLrDir} on disk; clients never see it.
          "qwen-image-2.1" = {
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
              "lk"
              "deepseek-ocr"
              "ornith-1.5-35b"
              "ornith-og"
              "comfyui"
            ]
            ++ lib.optionals qwenImageEnabled [ "qwen-image-2.1" ];
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
  # (the image unit serves the LoRA'd qwen-image-2.1-lr variant; it is
  #  unreferenced by llama-swap while qwenImageEnabled = false, but stays
  #  buildable and startable by hand: systemctl start gufo-image.service)
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

      # Memory ordering with the always-on readers (see llama-decision): gufo is
      # the agent, so when the pool runs out it is the last thing the kernel takes
      # and the first thing reclaim leaves alone. OOMScoreAdjust only orders the
      # kill; MemoryLow is what stops reclaim evicting 107 GiB of weights that are
      # already resident, and it is memory.low rather than memory.min precisely
      # because memory.min would refuse allocations elsewhere on the box instead of
      # merely preferring to take them from someone else.
      OOMScoreAdjust = -500;
      MemoryLow = "64G";

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
    description = "gufo: Qwen-Image-2.1 LoRA (served as qwen-image-2.1, OpenAI Images-compatible)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    startLimitIntervalSec = 300;
    startLimitBurst = 3;
    unitConfig.ConditionPathExists = "${qImageLrDir}/model_index.json";
    serviceConfig = {
      Type = "simple";
      User = "gufo";
      Group = "gufo";
      ExecStart = ''
        ${gufo}/bin/gufo serve image \
          --host 127.0.0.1 --port 8189 \
          --model ${qImageLrDir} \
          --served-model-name qwen-image-2.1
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
