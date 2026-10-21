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

  # ---------------------------------------------------------------------------
  # ComfyUI image
  #
  # No ROCm 10 in nixpkgs, so the base image stays docker.io/rocm/pytorch and nix
  # cannot build the image itself. What nix CAN own is the image's identity: the
  # tag below is a content hash of the Containerfile plus the ComfyUI pin, so any
  # edit to either one produces a tag that does not exist yet, and
  #
  #   * systemd.services.comfyui-image-build builds it at switch time -- the unit
  #     text embeds the tag, so bumping the pin changes the unit and a switch
  #     re-runs it (steady state: it exits immediately, the tag exists);
  #   * an ExecStartPre on podman-comfyui.service builds it lazily too, so
  #     llama-swap can never start ComfyUI on a tag that is missing (switch with
  #     no network, or a start before the eager build got there).
  #
  # The eager unit makes `nixos-rebuild switch` wait on the pull, which is the
  # point -- but if that ever hurts, either drive it from a timer instead of
  # wantedBy, or wrap ExecStart in `systemd-run --collect` so the unit returns
  # immediately and the build happens in the background. The lazy hook still
  # guarantees correctness either way.
  # ---------------------------------------------------------------------------
  comfyuiVersion = "v0.41.0";
  comfyuiContainerfile = ./containers/comfyui.Containerfile;
  comfyuiImageTag = builtins.substring 0 12 (
    builtins.hashString "sha256" "${builtins.readFile comfyuiContainerfile}\n${comfyuiVersion}\n"
  );
  comfyuiImage = "localhost/comfyui-rocm:rocm10-${comfyuiImageTag}";

  # This runs on the host, not as a nix build: it needs network and it writes into
  # the rootful store, which is where the quadlet container looks for its image
  # (a rootless `podman build` would be invisible to podman-comfyui.service).
  # The Containerfile has no COPY, so an empty directory is a complete context.
  comfyuiImageBuild = pkgs.writeShellScript "comfyui-image-build" ''
    set -euo pipefail
    podman=${pkgs.podman}/bin/podman
    tag=${comfyuiImage}

    # llama-swap's GPU holder and a switch can want the image at the same moment.
    # Absolute flock: when this runs as podman-comfyui's ExecStartPre it inherits
    # that unit's PATH (podman, coreutils, findutils, grep, sed, systemd), which
    # has no util-linux in it.
    exec 9>/run/lock/comfyui-image.lock
    ${pkgs.util-linux}/bin/flock 9

    if "$podman" image exists "$tag"; then
      echo "comfyui image $tag already present"
      exit 0
    fi

    # Retired tags pile up (~32 GB nominal each, though layers are shared so only
    # the delta is new). Deleting images is destructive, so it stays a manual
    # command; once the new tag is known good, drop the others:
    #   podman images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost/comfyui-rocm:rocm10-' | grep -v "$tag" | xargs -r podman rmi
    echo "building $tag (ComfyUI ${comfyuiVersion}); ~10 GB download on a cold cache"
    "$podman" build \
      --build-arg COMFYUI_VERSION=${comfyuiVersion} \
      --label ai.cunialino.comfyui.version=${comfyuiVersion} \
      --label ai.cunialino.comfyui.hash=${comfyuiImageTag} \
      -t "$tag" \
      -f ${comfyuiContainerfile} \
      ${pkgs.emptyDirectory}
  '';

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

  # -------------------------------------------------------------------------
  # llama.cpp presets: one roster, two lifecycles
  #
  # llamacppPresets is the single source of truth for the llama.cpp models on
  # this box -- id, display name, port, weights, per-model flags. It feeds the
  # router's preset file (generated, llamacppIni), the systemd units, the
  # llama-swap rows and the genai member list, and the Alloy scrape targets.
  # Adding a model is one entry here plus the weights on disk.
  #
  # It replaces ${llamaModelsDir}/config.ini as the roster. That file was
  # hand-edited and had already drifted: 6 [sections] against 7 llama-swap rows,
  # glm-4.5-air being a row with no section and no weights directory under
  # ${llamaModelsDir} -- a row that cannot be served and nothing compared the
  # two numbers to say so. It is gone from the roster. The file itself is left
  # on disk; nothing reads it after the switch.
  #
  # llamacppPerInstance picks the lifecycle, and only the lifecycle:
  #
  #   false (router)  ONE llama-server --models-preset <generated ini> on
  #                   ${llamaRouterPort}. Every preset row shares that one
  #                   process, so llama-swap's bookkeeping (one id == one
  #                   process) is a fiction, and genai's swap=false is what
  #                   keeps the fiction harmless -- the only eviction that ever
  #                   happens is "the whole group at once", which is exactly the
  #                   granularity a shared unit survives. llama.cpp's own
  #                   models-max = 2 is the memory bound: at most two instances
  #                   resident, LRU-evicted, with --kv-unified pooling their KV.
  #
  #   true (split)    one llama-server per preset: its own port, its own holder,
  #                   its own unit. id == process == unit becomes true, which is
  #                   what both per-preset metrics and a per-combination router
  #                   (llama-swap's matrix, #643/#646) need. GET /metrics on a
  #                   preset's own port is that instance's own answer, so a
  #                   scrape never loads anything, and
  #                   amdgpu_process_gtt_bytes{unit=...} attributes memory per
  #                   preset instead of lumping six into llama-cpp.service.
  #                   See the note above modules.alloy.jobs below.
  #
  #                   The cost, and the reason this is off until measured:
  #                   models-max goes with the router, so nothing bounds
  #                   residency but the agent group's exclusivity and
  #                   llamacppRowTtl below -- and each instance sizes its own KV
  #                   rather than sharing a pool. Six presets at ctx-size 262144
  #                   are over 124 GiB by a wide margin, and the box has no
  #                   swap. Measure one instance's footprint (the unit's own
  #                   GTT, amdgpu_process_gtt_bytes{unit="llama-cpp-ori.service"})
  #                   with gufo unloaded before flipping this; that is also the
  #                   number the matrix evict_costs would be written from.
  #
  #                   sleep-idle-seconds is dropped from the flags in this mode
  #                   on purpose: a --metrics scrape wakes a sleeping instance
  #                   (the same trap that keeps llamacpp-metrics.sh from probing
  #                   /health), so keeping it would make the scrape job a
  #                   warm-keeper, and llama-swap's own stop is the release.
  # -------------------------------------------------------------------------

  # Flip after measuring, not before. See the note above -- and the numbers are
  # now in (llamacppMeasured): the whole roster together is 175.85 GiB against a
  # 124 GiB box, which is what the note was afraid of.
  #
  # true, because the thing that makes residency safe without models-max is the
  # matrix, and the matrix needs one process per row to work at all: it evicts per
  # model, and on the shared back end "evict one model" is "stop the router for
  # the other five" (measured: 502 on the next sibling request). So this flag and
  # routing.router.use move together -- the router block above keys off it rather
  # than carrying its own knob, so the two cannot drift apart.
  llamacppPerInstance = true;

  # Idle unload for the llama.cpp rows in split mode, seconds of no requests.
  # This is what models-max = 2 became: not a capacity cap (llama-swap has no
  # such knob) but the bound on how long a walk through the presets can leave
  # 20-something GiB resident. Keep it well under "a working session".
  #
  #
  # 120 rather than 300, for the first switch under matrix. Co-residency is no
  # longer this knob's job -- no set declares more than llamacppCoResidentBudgetGiB
  # -- but the eviction order has never been observed on the real binary, and 120
  # caps how long a wrong answer stays resident. Move to 300 once
  # up{job="llamacpp"} shows presets being evicted by cost and not by accident.
  llamacppRowTtl = 120;

  # Flags every instance shares -- the [*] of the old config.ini, minus the two
  # router-only keys in llamacppRouterOnlyArgs.
  llamacppSharedArgs = {
    "n-gpu-layers" = 999;
    metrics = true;
    "cache-prompt" = true;
    parallel = 4;
    threads = 8;
    "flash-attn" = true;
    "kv-unified" = 1;
    "cache-type-k" = "q8_0";
    "cache-type-v" = "q8_0";
    jinja = 1;

    # Idle GPU load. llama.cpp's default --poll 50 busy-polls for work: upstream's
    # recipe for always-on deployments is --poll 0 (poll-batch and spec-draft-poll
    # both inherit --poll, so setting it once is enough -- they are explicit here
    # only so the inheritance is visible).
    poll = 0;
    "poll-batch" = 0;
  };

  # Router-only: how many instances may be resident at once (LRU-evicted), and
  # letting go of the GPU under an idle instance. The latter is llama.cpp#19379's
  # caveat -- sleep-idle releases compute but keeps the child attached with a few
  # hundred MiB (rocblas reserves its own scratch on the first call), so this
  # bounds busy GPU, not memory. Both are meaningless without a router.
  llamacppRouterOnlyArgs = {
    "models-max" = 2;
    "sleep-idle-seconds" = 300;
  };

  # id = the llama-swap row id = the --alias the instance reports = the label on
  # amdgpu_process_gtt_bytes in split mode. Ports are explicit rather than derived
  # from position, so adding a preset in the middle cannot move another one.
  llamacppPresets = {
    "qwen3.6" = {
      displayName = "Qwen3.6";
      port = 11441;
      args = {
        model = "${llamaModelsDir}/qwen3.6-35b-a3b/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
        mmproj = "${llamaModelsDir}/qwen3.6-35b-a3b/mmproj-F16.gguf";
        "batch-size" = 2048;
        "ubatch-size" = 2048;
        temp = 0.6;
        "top-k" = 20;
        "top-p" = 0.95;
        "min-p" = 0;
        "presence-penalty" = 0.0;
        "repeat-penalty" = 1.0;
        "ctx-size" = 262144;
        "spec-type" = "draft-mtp";
        "spec-draft-n-max" = 3;
      };
    };

    ori = {
      displayName = "Ori";
      port = 11442;
      args = {
        model = "${llamaModelsDir}/orion/TheDrummer_Orion-26B-A4B-v1-Q6_K_L.gguf";
        mmproj = "${llamaModelsDir}/orion/mmproj-TheDrummer_Orion-26B-A4B-v1-f16.gguf";
        "ctx-size" = 262144;
        "batch-size" = 2048;
        "ubatch-size" = 2048;
      };
    };

    lk = {
      displayName = "Lk";
      port = 11443;
      args = {
        model = "${llamaModelsDir}/gemma4-31B-loki/Gemma-4-31B-Loki-Scotoma-V2.0-Swa-4096.Q5_K_M.gguf";
        mmproj = "${llamaModelsDir}/gemma4-31B-loki/Gemma-4-31B-Loki-Scotoma-V2.0-Swa-4096.mmproj-f16.gguf";
        "ctx-size" = 262144;
      };
    };

    deepseek-ocr = {
      displayName = "DeepSeek-OCR";
      port = 11444;
      args = {
        model = "${llamaModelsDir}/deepseek-ocr/DeepSeek-OCR-Q8_0.gguf";
        mmproj = "${llamaModelsDir}/deepseek-ocr/mmproj-DeepSeek-OCR-Q8_0.gguf";
        temp = 0.0;
        "top-k" = 1;
        "top-p" = 1.0;
        "min-p" = 0.0;
        "presence-penalty" = 0.0;
        "repeat-penalty" = 1.0;
        "ctx-size" = 16384;
      };
    };

    ornith-og = {
      displayName = "Ornith-OG";
      port = 11445;
      args = {
        model = "${llamaModelsDir}/ornith-og/Ornith-1.5-35B-A3B-CRACK-Q6_K.gguf";
        mmproj = "${llamaModelsDir}/ornith-og/mmproj-Ornith-1.5-35B-A3B-f16.gguf";
        "batch-size" = 2048;
        "ubatch-size" = 2048;
        temp = 0.6;
        "top-k" = 20;
        "top-p" = 0.95;
        "min-p" = 0.0;
        "presence-penalty" = 0.0;
        "repeat-penalty" = 1.0;
        "ctx-size" = 262144;
        "spec-type" = "draft-mtp";
        "spec-draft-n-max" = 3;
        "image-min-tokens" = 1024;
      };
    };

    "ornith-1.5-35b" = {
      displayName = "Ornith-1.5-35B";
      port = 11446;
      args = {
        model = "${llamaModelsDir}/ornith-1.5-35b-a3b/Ornith-1.5-35B-A3B-Q6_K_L.gguf";
        mmproj = "${llamaModelsDir}/ornith-1.5-35b-a3b/mmproj-Ornith-1.5-35B-A3B-f16.gguf";
        "batch-size" = 2048;
        "ubatch-size" = 2048;
        temp = 0.6;
        "top-k" = 20;
        "top-p" = 0.95;
        "min-p" = 0.0;
        "presence-penalty" = 0.0;
        "repeat-penalty" = 1.0;
        "ctx-size" = 262144;
        "spec-type" = "draft-mtp";
        "spec-draft-n-max" = 3;
        "image-min-tokens" = 1024;
      };
    };
  };

  llamacppPresetNames = builtins.attrNames llamacppPresets;

  # -------------------------------------------------------------------------
  # What each model actually holds, and what may hold it at the same time
  #
  # Measured on this box 2026-10-21 against the live router: one preset asked for
  # through llama-swap, the agent group evicted first so nothing else held the
  # GPU, then that instance's own GTT read out of the amdgpu collector by pid
  # (llamacpp_preset_child_pid -> amdgpu_process_gtt_bytes, both already in
  # /run/alloy/textfile). On this hardware GTT is the whole reservation -- weights
  # plus the instance's KV at its own ctx-size -- which is why lk (41.60 GiB, the
  # smaller file) costs more than ori (28.42) and why the gguf size on disk is not
  # a usable input. loadSec is that same request's end-to-end latency including
  # the load: what evicting the model costs whoever asks for it next.
  #
  # Observations, not settings. Re-measuring is the sweep again (one request per
  # preset, one grep), never an edit here.
  # -------------------------------------------------------------------------
  llamacppMeasured = {
    "deepseek-ocr" = { gib = 5.14; loadSec = 4; };
    "ori" = { gib = 28.42; loadSec = 27; };
    "qwen3.6" = { gib = 29.08; loadSec = 12; };
    "ornith-og" = { gib = 35.12; loadSec = 14; };
    "ornith-1.5-35b" = { gib = 36.45; loadSec = 15; };
    "lk" = { gib = 41.60; loadSec = 13; };

    # 103265861632 bytes on gufo-llm.service's own DRM fd. Reload measured 17 s
    # warm / 61 s cold, and an eviction here does not cost somebody a slow first
    # token: it costs an in-flight agent turn its backing model. The cost below is
    # deliberately not that number (see llamacppMatrixEvictCosts).
    "${gufoServedName}" = { gib = 96.17; loadSec = 61; };

    # ComfyUI holds 0.15 GiB of GTT idle -- a torch process with nothing loaded --
    # and its working set mid-generation is NOT measured. loadSec is container
    # start to /system_stats answering. No gib: an unmeasured number does not
    # belong in a capacity rule, so image work keeps the GPU to itself (see
    # llamacppMatrixSets) until a generation is measured the same way.
    "comfyui" = { loadSec = 20; };
    "qwen-image-2.1" = { loadSec = 20; };
  };

  # What the genai presets may hold together: 124 GiB unified, minus the ~7 GiB
  # the box reports used with no model loaded at all, minus llama-decision's
  # 2.52 GiB (resident always, never swapped, never in a row here), minus ~10 GiB
  # that stays free because there is no swap on this host and compute buffers at
  # --batch-size 4096 / --parallel 4 arrive without warning. Text only.
  #
  # 80 admits every pair -- the largest, lk + ornith-1.5-35b, is 78.05 -- and only
  # those triples built around deepseek-ocr. Raising it past ~96 is how three of
  # them get loaded at once; lowering it below 78 splits the two big ones.
  llamacppCoResidentBudgetGiB = 80.0;

  # Every subset of the roster whose measured footprints fit the budget, keeping
  # only the maximal ones. Matrix permits any subset of a declared set, so [ori]
  # adds nothing beside [ori, lk] and the short list is the one a reader can check
  # by hand (6 presets, 64 subsets). Heaviest first, because ties in the solver
  # break on definition order.
  llamacppResidencySets =
    let
      gib = s: builtins.foldl' (t: n: t + llamacppMeasured.${n}.gib) 0.0 s;
      # Seed is [ [] ], not []: folding over [[]] doubles the list once per model,
      # folding over [] doubles nothing and yields no subsets at all -- which
      # renders as a matrix with only the agent and image sets, i.e. every preset
      # routable alone. Caught by reading the generated yaml, not by the build.
      subsets = builtins.foldl' (acc: n: acc ++ map (s: s ++ [ n ]) acc) [ [ ] ] llamacppPresetNames;
      fits = builtins.filter (s: s != [ ] && gib s <= llamacppCoResidentBudgetGiB) subsets;
      maximal = builtins.filter (
        s: ! builtins.any (o: builtins.length o > builtins.length s
          && builtins.all (x: builtins.elem x o) s)
        fits
      ) fits;
    in
    builtins.sort (a: b: gib a > gib b) maximal;

  # The matrix itself. Not hand-written: the capacity rule is the measured
  # numbers, so it is generated from them and stays true when a preset is added
  # or a footprint re-measured. Note what this is NOT -- the solver is
  # cost-ordered, not memory-aware, and upstream's position is that the admin
  # supplies configurations that work. The expressions are the capacity rule
  # (a third model can only be admitted by a set that has room for it); the costs
  # only decide which of the outside models pays for it.
  llamacppMatrixSets =
    let
      # "[a, b]" -> "( a & b )", single member -> bare id. Members sorted so the
      # expression is stable when the roster order changes.
      expr = s: if builtins.length s == 1 then builtins.head s
        else "( ${builtins.concatStringsSep " & " (builtins.sort (a: b: a < b) s)} )";
    in
    # An empty enumeration fails quietly and badly: with no residency set every
    # preset can only run alone, so the box still works and every switch between
    # presets pays a full reload. Assert the shape instead. The number also moves
    # when the budget or the roster does, which is the moment worth looking at.
    assert builtins.length llamacppResidencySets >= 2;
    {
      # The agent alone: 96.17 of 124 GiB. Not a preference, arithmetic -- no
      # preset fits beside it, the smallest pair being 101.31 GiB.
      agent = gufoServedName;

      # Image work alone, see the comfyui note above.
      image = "comfyui";
    }
    // lib.optionalAttrs qwenImageEnabled { image_qwen = "qwen-image-2.1"; }
    // builtins.listToAttrs (map (s: {
      name = "fits_${builtins.concatStringsSep "_" (builtins.sort (a: b: a < b) s)}";
      value = expr s;
    }) llamacppResidencySets);

  # Cost of losing a loaded model = seconds to bring it back, straight from the
  # sweep. Relative, which is all the solver reads. The agent is the one value not
  # taken from its own measurement: 61 s understates it, and above every preset
  # combined (101) it says what is actually meant -- keep the agent up if there is
  # any set at all that does not evict it.
  llamacppMatrixEvictCosts = builtins.listToAttrs (map (n: {
    name = n;
    value = if n == gufoServedName then 200 else llamacppMeasured.${n}.loadSec;
  }) (llamacppPresetNames ++ [ "comfyui" gufoServedName ]
    ++ lib.optionals qwenImageEnabled [ "qwen-image-2.1" ]));

  # Unit name of a preset. In split mode this is also the label that ties a
  # preset to its memory: amdgpu-metrics.sh reads the cgroup of every GPU process,
  # so the unit name IS the per-preset memory attribution.
  llamacppUnit = name: "llama-cpp-${name}.service";

  # The same renderer services.llama-cpp uses, so router and instance flags are
  # spelled identically (and `metrics = true` becomes a bare --metrics, not
  # `--metrics true`).
  llamacppArgsToFlags = args:
    lib.cli.toCommandLine (optionName: {
      option =
        if builtins.stringLength optionName > 1 then "--${optionName}" else "-${optionName}";
      sep = " ";
      explicitBool = false;
      formatArg = lib.generators.mkValueStringDefault { };
    }) args;

  # Values as the hand-written config.ini spelled them: `true`, not `1`, and 0.6,
  # not 0.600000. Nix renders a float with %f and a bool as 1/0 (which is also
  # what makes `metrics = true` become a bare --metrics on the command line, so
  # the bools stay bools); a parser reads either, but a generated file that diffs
  # against the file it replaces line for line is one a human can review, and
  # `metrics = 1` is not a token anyone reading this unit next is sure about.
  trimTrailingZeros = s:
    if lib.strings.hasSuffix "0" s then
      trimTrailingZeros (builtins.substring 0 (builtins.stringLength s - 1) s)
    else
      s;

  llamacppIniValue = v:
    if builtins.isBool v then (if v then "true" else "false")
    else if builtins.isFloat v then
      let
        parts = lib.strings.splitString "." (toString v);
        frac = trimTrailingZeros (builtins.elemAt parts 1);
      in
      "${builtins.head parts}.${if frac == "" then "0" else frac}"
    else
      toString v;

  llamacppIniSection = name: args: ''
    [${name}]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${llamacppIniValue v}") args)}
  '';

  # The preset file for router mode. Generated, so the roster and the file cannot
  # disagree -- the drift that produced the glm-4.5-air row. Keys come out in
  # alphabetical order (they are attribute sets); llama.cpp reads them by name.
  llamacppIni = pkgs.writeText "llama-cpp-presets.ini" (
    ''
      # Generated by this flake (hosts/strix_halo: llamacppSharedArgs and
      # llamacppPresets). Edit there; edits here are lost at the next switch.
    ''
    + lib.concatStringsSep "\n" (
      [ (llamacppIniSection "*" (llamacppSharedArgs // llamacppRouterOnlyArgs)) ]
      ++ map (n: llamacppIniSection n llamacppPresets.${n}.args) llamacppPresetNames
    )
  );

  # ---------------------------------------------------------------------------
  # Loopback endpoints of the serving stack, i.e. what Alloy reads (see
  # modules.alloy at the bottom of this file). Kept as bindings next to
  # decisionPort so that moving a port is one edit and the scrape config cannot
  # drift from the unit that owns it. The llama.cpp presets carry their own port
  # in llamacppPresets, loopback-only and reached through llama-swap like these;
  # llamaRouterPort is the single port they all share when llamacppPerInstance is
  # false.
  # ---------------------------------------------------------------------------
  llamaSwapPort = 11434;
  llamaRouterPort = 11435;
  gufoLlmPort = 8732;
  gufoImagePort = 8189;
  comfyuiPort = 8188;

  # What the monitoring does with the presets depends on llamacppPerInstance, and
  # both cases exist because of one llama.cpp detail: in router mode GET /metrics
  # is not a management endpoint -- it is a task result produced by ONE loaded
  # context -- so the router answers it by proxying the request to the instance
  # named by ?model=, through the same queue as a completion. Naming a preset is
  # what loads it. Hence the textfile collector in router mode
  # (modules.alloy.textfile.llamacpp, sys_mods/alloy/llamacpp-metrics.sh: residency
  # read from /proc, nothing sent to the router) and a plain scrape job in split
  # mode, where each preset answers on its own port and a scrape cannot load a
  # thing. See the llamacpp.* bullet above modules.alloy for the metric-by-metric
  # version of this.

  # ROCm leaves the GPU busy at idle when several HW queues are in play;
  # upstream's fix is to default GPU_MAX_HW_QUEUES=1 on HIP (llama.cpp#24237).
  # Checked against the installed build (llama-cpp 0.5.0 b11146, commit 7fe450e):
  # `strings` over the binary and bin/libggml-hip.so finds no GPU_MAX_HW_QUEUES at
  # all, so that default is NOT in this build and the var has to come from the
  # unit. It must be in the environment of llama-server itself, not of the unit's
  # wrapper -- read by HIP at context creation -- and in router mode the children
  # inherit it from there. Drop this once nixpkgs' llama-cpp-rocm carries #24237.
  llamacppEnvironment = [ "LLAMA_CACHE=/var/cache/llama-cpp" "GPU_MAX_HW_QUEUES=1" ];

  # ---------------------------------------------------------------------------
  # The llama.cpp units, as an inline module.
  #
  # A module rather than a few lines of config because the unit names in split
  # mode are generated from the roster, which needs a whole
  # `systemd.services = <set>` assignment -- and this file already assigns
  # `systemd.services.<name>` by path in half a dozen places, which Nix reads as
  # the key `systemd.services` defined twice. Its own module is how a generated
  # set gets in.
  # ---------------------------------------------------------------------------
  llamacppUnitsModule = { ... }: {
    # DynamicUser cannot read ${llamaModelsDir} (0750 elia:users); run as elia,
    # who is in `render`/`video` and already gets unlimited memlock. Everything else
    # the per-preset units below carry is services.llama-cpp's own hardening,
    # repeated because those units are not built by that module (it is only enabled
    # in router mode).
    #
    # One assignment for both modes: a second `systemd.services = ...` in the same
    # file is a duplicate key, and router mode needs llama-cpp plus ComfyUI's two
    # lines in here while split mode needs one unit per preset and ComfyUI left to
    # its own row.
    systemd.services =
      let
        # -----------------------------------------------------------------------
        # Split mode: one llama-server per preset.
        #
        # Same shape as the router unit and the same rule as every other inference
        # unit here: NOT wantedBy multi-user.target. llama-swap starts them through
        # swapUnitHolder and stops them on the way out, which is now a per-preset
        # stop -- `systemctl stop llama-cpp-ori.service` takes Ori and nothing else.
        #
        # Restart=on-failure with a tight StartLimit is the one deviation from the
        # module. A preset that dies of OOM must not come back every few seconds and
        # fight the next model for the pool; three tries and the unit goes to failed,
        # where it stays until someone resets it. The holder cannot see that: it ran
        # `systemctl start` once and llama-swap still believes the row is loaded, so
        # recovery is `systemctl reset-failed <unit> && systemctl start <unit>`. The
        # same gap exists in router mode -- rarer, because the router dying takes
        # the whole group with it -- and closing it means a health check inside the
        # holder, which is a separate call.
        # -----------------------------------------------------------------------
        instanceUnits = builtins.listToAttrs (
          map (
            name:
            {
              name = "llama-cpp-${name}";
              value = {
                description = "llama.cpp: ${llamacppPresets.${name}.displayName} (${name})";
                wants = [ "network.target" ];
                after = [ "network.target" ];

                serviceConfig = {
                  ExecStart = toString [
                    (lib.getExe' pkgs.llama-cpp-rocm "llama-server")
                    (llamacppArgsToFlags (
                      llamacppSharedArgs
                      // llamacppPresets.${name}.args
                      // {
                        # What the instance reports as its model name, so it has to
                        # be the llama-swap row id: the body is forwarded untouched.
                        alias = name;
                        host = "127.0.0.1";
                        port = llamacppPresets.${name}.port;
                      }
                    ))
                  ];
                  ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
                  Restart = "on-failure";
                  RestartSec = 30;

                  DynamicUser = false;
                  User = username;
                  Group = "users";
                  # Shared with the router-mode unit's state/cache dirs: prompt cache
                  # and nothing per-preset.
                  StateDirectory = "llama-cpp";
                  CacheDirectory = "llama-cpp";
                  WorkingDirectory = "/var/lib/llama-cpp";
                  Environment = llamacppEnvironment;
                  LimitMEMLOCK = "infinity";

                  AmbientCapabilities = [ "" ];
                  CapabilityBoundingSet = [ "" ];
                  LockPersonality = true;
                  MemoryDenyWriteExecute = true;
                  NoNewPrivileges = true;
                  # Required for GPU support.
                  PrivateDevices = false;
                  PrivateMounts = true;
                  PrivateTmp = true;
                  PrivateUsers = true;
                  ProcSubset = "pid";
                  ProtectClock = true;
                  ProtectControlGroups = true;
                  ProtectHome = true;
                  ProtectHostname = true;
                  ProtectKernelLogs = true;
                  ProtectKernelModules = true;
                  ProtectKernelTunables = true;
                  ProtectProc = "invisible";
                  ProtectSystem = "strict";
                  RemoveIPC = true;
                  RestrictAddressFamilies = [
                    "AF_INET"
                    "AF_INET6"
                    "AF_UNIX"
                  ];
                  RestrictNamespaces = true;
                  RestrictRealtime = true;
                  RestrictSUIDSGID = true;
                  SystemCallArchitectures = "native";
                  SystemCallErrorNumber = "EPERM";
                  SystemCallFilter = [
                    "@system-service"
                    "~@privileged"
                  ];
                };

                unitConfig.StartLimitIntervalSec = 600;
                unitConfig.StartLimitBurst = 3;
              };
            }
          ) llamacppPresetNames
        );
      in
      (lib.optionalAttrs (!llamacppPerInstance) {
        llama-cpp = {
          wantedBy = lib.mkForce [ ];
          serviceConfig = {
            DynamicUser = lib.mkForce false;
            User = username;
            Group = "users";
            LimitMEMLOCK = "infinity";
            # Only what the module does not set. It already exports
            # LLAMA_CACHE=/var/cache/llama-cpp for this unit; the split units, who
            # have no module behind them, take the whole llamacppEnvironment.
            Environment = [ "GPU_MAX_HW_QUEUES=1" ];
          };

          # ComfyUI rides the llama.cpp router's lifecycle. Every llama.cpp preset
          # is one router unit, so hooking the container to that unit covers all of
          # them at once -- llama-swap has no "start this model alongside that one"
          # primitive (its only preload hook, hooks.on_startup, fires when
          # llama-swap boots).
          #
          # In split mode both this and the PartOf= below are gone: ComfyUI has its
          # own row, and that row's holder stops podman-comfyui.service when
          # llama-swap evicts it, which is the thing PartOf= was approximating.
          # Hanging it off one of six preset units would be worse than the hack it
          # replaces.
          #
          # Wants=, not Requires=: a failing ComfyUI must never take the chat
          # presets down, and `systemctl stop podman-comfyui.service` by hand must
          # not stop the router. No After= either -- ComfyUI's cold torch import runs
          # in parallel with llama-server instead of delaying it.
          unitConfig.Wants = [ "podman-comfyui.service" ];
        };

        # One-way stop propagation (systemd.unit(5), PartOf=): stopping or
        # restarting llama-cpp.service propagates here, never the reverse. This is
        # what unloads the container when the `agent` group takes the GPU --
        # llama-swap evicts the llama holder, the holder stops the router unit, the
        # container follows. Note it also fires when the llama-swap UI stops any one
        # preset row, which already drops the whole shared router (see the
        # `presetRow` binding below).
        podman-comfyui.unitConfig.PartOf = [ "llama-cpp.service" ];
      })
      // (lib.optionalAttrs llamacppPerInstance instanceUnits);
  };

in

{
  imports = [
    ./hardware-config.nix
    sys_dir
    # The llama.cpp units, generated from the roster. See its comment in the let
    # block for why they cannot live in this attrset.
    llamacppUnitsModule
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

      # Image tag is derived from the Containerfile + ComfyUI pin above, and
      # systemd.services.comfyui-image-build (switch time) plus an ExecStartPre on
      # podman-comfyui.service build it. Nothing to do by hand any more; the old
      # `podman build -t localhost/comfyui-rocm:rocm10 ...` is only for debugging.
      containers.comfyui = {
        image = comfyuiImage;
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

  # Builds the ComfyUI image when the Containerfile/pin changes. Type=oneshot and
  # RemainAfterExit so a switch starts it once; a no-op when the tag exists.
  systemd.services.comfyui-image-build = {
    description = "Build ${comfyuiImage} for the current ComfyUI pin";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = comfyuiImageBuild;
      # cold cache: base pull + ComfyUI requirements + the RES4LYF deps
      TimeoutStartSec = 3600;
    };
  };

  # Lazy backstop for every path that starts ComfyUI (llama-swap's GPU holder,
  # a manual systemctl). Quadlet already sets ExecStartPre to `podman rm -f`, so
  # append rather than overwrite; the unit has TimeoutStartSec=0, so a long build
  # cannot be killed mid-pull.
  systemd.services.podman-comfyui.serviceConfig.ExecStartPre = lib.mkAfter [
    "+${comfyuiImageBuild}"
  ];

  # ---------------------------------------------------------------------------
  # Native ROCm inference (llama.cpp only; ComfyUI stays a podman container)
  #
  # The unit exists but is NOT wantedBy multi-user.target, which mirrors the old
  # `autoStart = false`: nothing grabs the GPU until something starts it.
  # Inference is meant to be driven through llama-swap (see below), not by
  # enabling this.
  # ---------------------------------------------------------------------------

  services.llama-cpp = lib.optionalAttrs (!llamacppPerInstance) {
    enable = true;
    package = pkgs.llama-cpp-rocm;
    # Deliberately only these three. services.llama-cpp renders every entry of
    # `settings` onto the command line, and the shared flags are already in the
    # preset file's [*] -- passing them twice would make the router unit differ
    # from the one running today for no reason, and "which value wins" (CLI vs
    # the per-preset section) is not a question worth having.
    settings = {
      # Generated from the roster above; absolute host paths for the weights, so
      # the same shape the hand-written config.ini had (router mode: one process,
      # every preset selectable by the requested model name).
      models-preset = "${llamacppIni}";
      host = "127.0.0.1";
      # llama-swap owns 11434 now; the router answers on a loopback-only port and
      # is reached through it.
      port = llamaRouterPort;
    };
  };


  # The llama.cpp units -- the router unit's overrides in router mode, one unit
  # per preset in split mode, and ComfyUI's Wants=/PartOf= -- live in
  # llamacppUnitsModule, defined in the let block above next to the roster. They
  # have to be there: generated unit names need a whole `systemd.services = <set>`
  # assignment, and this file already assigns systemd.services.<name> by path,
  # which Nix reads as the same key defined twice.

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
          --metrics \
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
      # request body untouched, so an ID must be a llama.cpp preset id (a key of
      # llamacppPresets, which is both the [section] name in the generated preset
      # file and, in split mode, the instance's --alias) or gufo's
      # --served-model-name. Display names carry no backend prefix; ids are
      # already unique across all models, so nothing here can collide.
      models =
        let
          # One row per preset, straight off the roster. Both lifecycles keep the
          # same row id and display name; what changes is what stands behind it.
          #
          # Router mode: one holder, one port, every row the same llama-server.
          # The sharp edge that comes with sharing it -- the holder's teardown is
          # `systemctl stop llama-cpp.service`, so stopping any single row here
          # (llama-swap UI, /api/models/<id>/stop) drops the router for the rest
          # of them. Nothing else unloads them: genai is swap=false, so in
          # practice they go only when the agent group takes the GPU. That is
          # also why NO ttl is set on these rows in router mode: an idle unload
          # there is not an idle Ori going away, it is the whole router.
          #
          # Split mode: holder and port per preset, so a stop stops one model, a
          # scrape hits one model, and `ttl` becomes meaningful -- it is what
          # replaced llama.cpp's models-max = 2 (llamacppRowTtl).
          presetRow = name: p: {
            name = p.displayName;
            cmd = swapUnitHolder (
              if llamacppPerInstance then llamacppUnit name else "llama-cpp.service"
            );
            proxy = "http://127.0.0.1:${
              toString (if llamacppPerInstance then p.port else llamaRouterPort)
            }";
            checkEndpoint = "/health";
          }
          // lib.optionalAttrs llamacppPerInstance {
            ttl = llamacppRowTtl;
          };
        in
        {
          "${gufoServedName}" = {
            name = "Qwen3.8 Flash-Next";
            cmd = swapUnitHolder "gufo-llm.service";
            proxy = "http://127.0.0.1:8732";
            checkEndpoint = "/health";
          };

          # glm-4.5-air is gone: it was a row with no preset behind it and no
          # weights under ${llamaModelsDir}. See the roster note above.
        }
        // builtins.listToAttrs (map (n: {
          name = n;
          value = presetRow n llamacppPresets.${n};
        }) llamacppPresetNames)
        // {
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
          # Gated out of both engines, which is not the same thing in each: under
          # `group` a row in no group is not routable at all (the engine builds its
          # process map from group membership alone, router/group.go), while under
          # `matrix` a model in no set IS routable but only ever alone. Turning the
          # row off entirely is the one behaviour both engines agree on, so the
          # entry disappears rather than being left unroutable-by-omission.
          #
          # As of 2026-10-21 this backend does not load at all: gufo-image exits on
          # "cannot read Qwen-Image metadata:
          # /var/lib/gufo-models/qwen-image-2.1-lr/text_encoder/config.json" and
          # then hits start-limit-hit. The weights on disk are incomplete; nothing
          # in this file can fix that. ID must equal the gufo-image unit's --served-model-name: the
          # body is forwarded untouched, so this is exactly the string clients
          # send. The LoRA lives at ${qImageLrDir} on disk; clients never see it.
          "qwen-image-2.1" = {
            name = "Qwen-Image-2.1";
            cmd = swapUnitHolder "gufo-image.service";
            proxy = "http://127.0.0.1:8189";
            checkEndpoint = "/health";
          };
        };

      # Which engine, and why the answer depends on llamacppPerInstance.
      #
      # group (router mode): one process behind every row, so llama-swap cannot
      # unload one model without unloading all of them. The only eviction this
      # engine can express that the shared backend survives is group-wide, which
      # is exactly what agent/genai say.
      #
      # matrix (split mode): eviction is per model, and with one process per row
      # per-model eviction is real -- stopping a row stops that unit and nothing
      # else. The combination was tested and does not work the other way: matrix
      # on the shared backend produced HTTP 502 on the next sibling request
      # (dial tcp 127.0.0.1:11520: connect: connection refused) where the group
      # engine on the same topology returned 200 for all of them. So the engine
      # follows the lifecycle rather than being set independently.
      #
      # What matrix buys, with numbers instead of flags: gufo runs alone because
      # nothing fits beside it, any two presets fit, three mostly do not, and the
      # model that pays for a new arrival is the cheapest to reload. groups could
      # not express any of that; it had genai = "everything at once, unbounded",
      # which is only safe while llama.cpp's models-max holds the back end down.
      routing.router =
        if llamacppPerInstance then {
          use = "matrix";
          settings.matrix = {
            evict_costs = llamacppMatrixEvictCosts;
            sets = llamacppMatrixSets;
          };
        } else {
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
              members = llamacppPresetNames ++ [ "comfyui" ]
              ++ lib.optionals qwenImageEnabled [ "qwen-image-2.1" ];
            };
          };
        };

      # The agent goes to the front of the queue. This is not a latency
      # preference, it is an outage note: FIFO means a request for any model waits
      # behind whatever the router is trying to bring up, and a row whose backend
      # cannot load holds the whole box for healthCheckTimeout. Observed 2026-10-21
      # 23:02 -> 23:17 -- gufo-image exited on a missing text_encoder/config.json,
      # llama-swap retried the dead port for 15 minutes, and every other model
      # including this agent was blocked behind it. Priority cannot fix that
      # broken row, but it does mean the agent is served as soon as it is the
      # router's turn instead of last.
      routing.scheduler = {
        use = "fifo";
        settings.fifo.priority = {
          "${gufoServedName}" = 10;
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


  # The ConditionFileNotEmpty that used to sit here gated on
  # ${llamaModelsDir}/config.ini, because llama-server aborts when --models-preset
  # names a file that is not there and the unit crash-looped instead of failing
  # cleanly. The preset file is generated into the store now, so the condition
  # would always be true; the failure mode it guarded is gone by construction.
  #
  # What DID survive the change, and is worth knowing: (ConditionPathIsNonEmpty is
  # only valid in [Path] units -- systemd drops it in [Unit] with "Unknown key",
  # which is how the crash loop was written in the first place.)

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

  # ---------------------------------------------------------------------------
  # Metrics out: Alloy -> Prometheus in the cluster
  #
  # Push, not scrape. This box is not a k3s node and its serving ports stay its
  # own business (nothing reaches in over the LAN for monitoring); Alloy reads
  # loopback and remote_writes to the cluster's Prometheus, which has a VIP of
  # its own on 192.168.0.203 -- so the destination survives rescheduling, which
  # is the reason to push to a VIP rather than to a node address. The receiver
  # needs `--web.enable-remote-write-receiver`, and 9090 is opened on the
  # cluster interfaces by the k3s module for exactly this traffic.
  #
  # Alloy keeps a WAL on disk, so a cluster that is down for an hour is a gap
  # that closes by itself, not a hole in the history.
  #
  # What each source contributes:
  #   * node  -- Alloy's built-in node_exporter. `node_memory_*` is the host
  #     half of the unified pool: on a machine where the iGPU's memory IS RAM,
  #     MemAvailable is the number that says whether the next model loads or the
  #     OOM killer does (the history of that is the MemoryLow/OOMScoreAdjust
  #     notes on gufo-llm and llama-decision).
  #   * amdgpu.* -- the textfile collector (sys_mods/alloy/amdgpu-metrics.sh).
  #     gtt_used is where weights land on this APU; vram_used is the 1 GiB BAR
  #     and nearly useless on its own. Per-process GTT + RSS, labelled with the
  #     owning systemd unit, is the "who took the memory" answer.
  #   * comfyui.* -- also textfile: ComfyUI has no /metrics upstream, so the
  #     collector translates its /system_stats and /prompt (queue depth, torch's
  #     own view of the pool). Its GPU footprint, like every other workload's,
  #     comes from the amdgpu per-process series.
  #   * gufo, llama-swap, llama-decision -- the serving stack's own counters
  #     (tokens, cache hit rate, queue, spec-decode acceptance). All three are
  #     processes that are already up and answer /metrics themselves, so a scrape
  #     is never what starts them.
  #   * llamacpp.* -- which of these two it is depends on llamacppPerInstance,
  #     and the difference is the reason the split is worth doing:
  #
  #     router mode (llamacppPerInstance = false): textfile, never a scrape. The
  #     router loads by model name and answers /metrics by proxying the request to
  #     that model through the same queue as a completion, so scraping it per
  #     preset is what loads every preset (models-max then evicts the LRU to make
  #     room, and the box spends the day loading and unloading because a dashboard
  #     asked whether they were loaded). The collector says what is resident
  #     without asking (llamacpp_preset_loaded) and reports the port it answers on
  #     while it is.
  #
  #     split mode (llamacppPerInstance = true): a real scrape job, one target per
  #     preset on its own loopback port, labelled preset= and unit=. There the
  #     answer is the instance's own, so a scrape can never load anything -- which
  #     is precisely what the __param_model assertion in sys_mods/alloy refuses,
  #     and what the router makes unavoidable. Read the two together:
  #       up{job="llamacpp",preset="ori"}  ==  resident AND answering, which the
  #       textfile's loaded=1 could not say (it was process existence, and read 1
  #       across the whole load window). "Configured" is no longer a metric -- it
  #       is llamacppPresets in this file, and the unit= label is what joins a
  #       preset to amdgpu_process_gtt_bytes, i.e. per-preset memory attribution
  #       for the first time. Targets that are not resident fail to connect; that
  #       is the expected state and it costs nothing.
  # ---------------------------------------------------------------------------
  modules.alloy = {
    enable = true;

    pushUrl = "http://192.168.0.203:9090/api/v1/write";

    # The push leaves over eth; nothing else may. Same rule as the gufo units.
    allowedNetworks = [
      "127.0.0.0/8"
      "::1/128"
      "192.168.0.0/24"
    ];

    nodeExporter = {
      enable = true;
      # 10s, to meet the collector halfway. textfile.interval above is 10s, so at
      # 15s the pool totals were on average 5s old on the graph and up to 10s --
      # which on a box whose whole failure mode is a pool drained to 0 GiB is the
      # wrong direction of wrong. Below 10s would be pointless for amdgpu/ComfyUI
      # (same number, shipped twice) and the kernel series do not need it either.
      #
      # Cost, measured rather than guessed: the box ships ~89 samples/s today
      # (central Prometheus is taking ~14.7k/s), 867 of those series being this
      # job. 10s adds ~29/s -- about 0.2% of the server's ingest, and no new
      # series, so the head stays where it is.
      scrapeInterval = "10s";
      scrapeTimeout = "5s";
    };

    # Kept slow on purpose: 749 series of pipeline internals, and the counters
    # that matter here (remote_write failures, WAL pending) move over minutes.
    selfScrape = true;
    selfScrapeInterval = "30s";

    textfile = {
      # 10 s: fine for "is anything eating the pool" and cheap enough to run
      # forever. The GRBM read inside amdgpu_top is what costs (it keeps the
      # iGPU from its deepest sleep), not the scrape.
      interval = "10s";
      amdgpu.enable = true;
      comfyui = {
        enable = true;
        url = "http://127.0.0.1:${toString comfyuiPort}";
      };
      llamacpp = {
        # Router-only: with one instance per preset there is nothing to infer
        # from /proc, and the collector's llamacpp_router_up would sit at 0.
        #
        # Flipping this off does NOT stop the metrics: the collector owns
        # /run/alloy/textfile/llamacpp.prom only while it runs, and node_exporter's
        # textfile collector re-exports whatever sits on the path. After the switch
        # to per-instance the file was 24 minutes dead (mtime 23:26:49) and
        # Prometheus was still being handed all 20 series -- fresh samples, frozen
        # values, indistinguishable from an idle box on the other end. Delete it
        # when toggling:
        #   sudo rm /run/alloy/textfile/llamacpp.prom
        # (a reboot clears it too; /run is not persistent.)
        enable = !llamacppPerInstance;
        url = "http://127.0.0.1:${toString llamaRouterPort}";
        configIni = "${llamacppIni}";
        # The instance list (GET /v1/models) is answered by the router itself and
        # would add "queued/loading" to "resident". Left off until the first
        # interval has been watched for a join: request line in llama-cpp.service
        # -- see the option description.
        probeModels = false;
      };
    };

    jobs = [
      {
        name = "gufo";
        description = "gufo: /metrics on both units (loopback). Down == that engine is not loaded.";
        targets = [
          {
            addr = "127.0.0.1:${toString gufoLlmPort}";
            labels = { service = "gufo-llm.service"; };
          }
          {
            addr = "127.0.0.1:${toString gufoImagePort}";
            labels = { service = "gufo-image.service"; };
          }
        ];
        # 5s like the rest, against the warning written here earlier -- and the
        # warning was checked rather than kept: over 6 h at 30s this job received
        # 720 of 720 scrapes with zero changes in up, through prefills of this
        # agent's 100k-token sessions included. /metrics is not fragile here; what
        # it costs is one extra read per 5s on a single worker.
        #
        # Timeout stays below the interval (module rule: an overlapping timeout
        # turns a slow answer into a backlog). If up{job="gufo"} ever starts
        # moving without the unit moving --
        #   changes(up{job="gufo"}[6h])
        # -- this line, 5s -> 10s, is the one to walk back. Nothing else depends
        # on gu being polled fast.
        scrapeInterval = "5s";
        scrapeTimeout = "4s";
      }
      {
        name = "llama-swap";
        description = "llama-swap: always on, host counters of the serving path (llamaswap_*).";
        targets = [
          { addr = "127.0.0.1:${toString llamaSwapPort}"; }
        ];
        # 5s. This is the job that shows a swap in progress, and a swap is 4-27 s
        # here; a Go process answering from memory, with no worker to get in front
        # of. 50 series, so the whole job is 10 samples/s.
        scrapeInterval = "5s";
        scrapeTimeout = "3s";
      }
      {
        name = "llama-decision";
        description = "llama-decision (d3-nano): always on, needs --metrics in its ExecStart.";
        targets = [
          { addr = "127.0.0.1:${toString decisionPort}"; }
        ];
        scrapeInterval = "5s";
        scrapeTimeout = "3s";
      }
    ]
    ++ lib.optionals llamacppPerInstance [
      {
        name = "llamacpp";
        description = ''
          llama.cpp presets: one target each, on its own loopback port. A scrape
          here cannot load a model -- it lands on the instance that is already
          running -- so down means not resident, and the tokens/KV/queue series
          only exist while the preset is up. unit= joins to
          amdgpu_process_gtt_bytes{unit=...}, which is the per-preset footprint
          the matrix evict_costs are meant to be written from.

          5s, because residency here is short and the events are the point: the
          first measurement on this box (23:43, qwen3.6 resident 24 s) produced no
          up sample at all at 30s. Loads run 4-27 s, so the interval has to sit
          under the shortest of them to see one happen at all -- 5s gives the
          4-second deepseek-ocr load a single sample, which is all an up needs to
          be true.

          Six loopback targets, and five of them are refused almost all the time:
          that is the expected state, it is what down is for, and it costs a
          connect that fails immediately. 38 series across the job = ~8 samples/s
          worst case.
        '';
        targets = map (n: {
          addr = "127.0.0.1:${toString llamacppPresets.${n}.port}";
          labels = {
            preset = n;
            unit = llamacppUnit n;
          };
        }) llamacppPresetNames;
        scrapeInterval = "5s";
        scrapeTimeout = "3s";
      }
    ];
  };
}
