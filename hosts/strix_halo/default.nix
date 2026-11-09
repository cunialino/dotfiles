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

  comfyuiVersion = "v0.41.0";

  comfyuiModelId = "comfyui_auto";

  comfyuiContainerfile = ./containers/comfyui.Containerfile;
  comfyuiImageTag = builtins.substring 0 12 (
    builtins.hashString "sha256" "${builtins.readFile comfyuiContainerfile}\n${comfyuiVersion}\n"
  );
  comfyuiImage = "localhost/comfyui-rocm:rocm10-${comfyuiImageTag}";

  comfyuiImageBuild = pkgs.writeShellScript "comfyui-image-build" ''
    set -euo pipefail
    podman=${pkgs.podman}/bin/podman
    tag=${comfyuiImage}

    exec 9>/run/lock/comfyui-image.lock
    ${pkgs.util-linux}/bin/flock 9

    if "$podman" image exists "$tag"; then
      echo "comfyui image $tag already present"
      exit 0
    fi

    echo "building $tag (ComfyUI ${comfyuiVersion}); ~10 GB download on a cold cache"
    "$podman" build \
      --build-arg COMFYUI_VERSION=${comfyuiVersion} \
      --label ai.cunialino.comfyui.version=${comfyuiVersion} \
      --label ai.cunialino.comfyui.hash=${comfyuiImageTag} \
      -t "$tag" \
      -f ${comfyuiContainerfile} \
      ${pkgs.emptyDirectory}
  '';

  decisionId = "d3-nano";
  decisionGguf = "${llamaModelsDir}/d3-nano/vllm-d3-nano-Q8_0.gguf";
  decisionPort = 11436;

  gufoModelsDir = "/var/lib/gufo-models";
  flashNextDir = "${gufoModelsDir}/qwen3.8-flash-next-v31";
  flashNextShard1 = "${flashNextDir}/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
  flashNextMtp = "${flashNextDir}/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf";
  qImageLrDir = "${gufoModelsDir}/qwen-image-2.1-lr";
  gufo = inputs.gufo.packages.x86_64-linux.default;
  gufoServedName = "qwen3.8-flash-next";
  gufoCacheDir = "/var/lib/gufo/cache";

  qwenImageEnabled = false;

  llamaCppMain = true;

  llamaCppRocm10 = true;

  rocm10Pkgs = inputs.nixpkgs-rocm10.legacyPackages.${pkgs.system};

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
    "${pkg}/bin/llama-swap-holder-${unit}";

  llamacppPerInstance = true;

  llamacppRowTtl = 120;

  llamacppSharedArgs = {
    "n-gpu-layers" = 999;
    metrics = true;
    "cache-prompt" = true;
    parallel = 4;
    threads = 8;
    "flash-attn" = "on";
    "kv-unified" = true;
    "cache-type-k" = "q8_0";
    "cache-type-v" = "q8_0";
    jinja = true;

    poll = 0;
    "poll-batch" = 0;
  };

  llamacppRouterOnlyArgs = {
    "models-max" = 2;
    "sleep-idle-seconds" = 300;
  };

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

    tt = {
      displayName = "Tt";
      port = 11447;
      args = {
        model = "${llamaModelsDir}/gemma4-31B-br/model-Q4_K_S.gguf";
        mmproj = "${llamaModelsDir}/gemma4-31B-br/mmproj-f16.gguf";
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

  llamacppMeasured = {
    "deepseek-ocr" = { gib = 5.14; loadSec = 4; };
    "ori" = { gib = 28.42; loadSec = 27; };
    "qwen3.6" = { gib = 29.08; loadSec = 12; };
    "ornith-og" = { gib = 35.12; loadSec = 14; };
    "ornith-1.5-35b" = { gib = 36.45; loadSec = 15; };
    "lk" = { gib = 41.60; loadSec = 13; };
    "tt" = { gib = 37.8; loadSec = 12; };

    "${gufoServedName}" = { gib = 96.17; loadSec = 61; };

    "${comfyuiModelId}" = { loadSec = 20; };
    "qwen-image-2.1" = { loadSec = 20; };
  };

  llamacppCoResidentBudgetGiB = 80.0;

  llamacppResidencySets =
    let
      gib = s: builtins.foldl' (t: n: t + llamacppMeasured.${n}.gib) 0.0 s;
      subsets = builtins.foldl' (acc: n: acc ++ map (s: s ++ [ n ]) acc) [ [ ] ] llamacppPresetNames;
      fits = builtins.filter (s: s != [ ] && gib s <= llamacppCoResidentBudgetGiB) subsets;
      maximal = builtins.filter (
        s: ! builtins.any (o: builtins.length o > builtins.length s
          && builtins.all (x: builtins.elem x o) s)
        fits
      ) fits;
    in
    builtins.sort (a: b: gib a > gib b) maximal;

  llamacppMatrixSets =
    let
      # "[a, b]" -> "( a & b )", single member -> bare id. Members sorted so the
      # expression is stable when the roster order changes.
      expr = s: if builtins.length s == 1 then builtins.head s
        else "( ${builtins.concatStringsSep " & " (builtins.sort (a: b: a < b) s)} )";
    in
    assert builtins.length llamacppResidencySets >= 2;
    {
      agent = gufoServedName;
      image = comfyuiModelId;
    }
    // lib.optionalAttrs qwenImageEnabled { image_qwen = "qwen-image-2.1"; }
    // builtins.listToAttrs (map (s: {
      name = "fits_${builtins.concatStringsSep "_" (builtins.sort (a: b: a < b) s)}";
      value = expr s;
    }) llamacppResidencySets);

  llamacppMatrixEvictCosts = builtins.listToAttrs (map (n: {
    name = n;
    value = if n == gufoServedName then 200 else llamacppMeasured.${n}.loadSec;
  }) (llamacppPresetNames ++ [ comfyuiModelId gufoServedName ]
    ++ lib.optionals qwenImageEnabled [ "qwen-image-2.1" ]));

  llamacppUnit = name: "llama-cpp-${name}.service";

  llamacppOptionalValueArgs = [ "flash-attn" ];

  llamacppArgsToFlags = args:
    assert lib.all (k: builtins.isString (args.${k} or "")) llamacppOptionalValueArgs;
    lib.cli.toCommandLine (optionName: {
      option =
        if builtins.stringLength optionName > 1 then "--${optionName}" else "-${optionName}";
      sep = " ";
      explicitBool = false;
      formatArg = lib.generators.mkValueStringDefault { };
    }) args;

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

  llamaSwapPort = 11434;
  llamaRouterPort = 11435;
  gufoLlmPort = 8732;
  gufoImagePort = 8189;
  comfyuiPort = 8188;

  llamacppEnvironment = [ "LLAMA_CACHE=/var/cache/llama-cpp" "GPU_MAX_HW_QUEUES=1" ];

  llamacppUnitsModule = { ... }: {
    systemd.services =
      let
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
            Environment = [ "GPU_MAX_HW_QUEUES=1" ];
          };

          unitConfig.Wants = [ "podman-comfyui.service" ];
        };

        podman-comfyui.unitConfig.PartOf = [ "llama-cpp.service" ];
      })
      // (lib.optionalAttrs llamacppPerInstance instanceUnits);
  };

in

{
  imports = [
    ./hardware-config.nix
    sys_dir
    llamacppUnitsModule
  ];


  nixpkgs.overlays = lib.optionals llamaCppMain [
    (
      final: prev:
      {
        llama-cpp = (
          prev.llama-cpp.override {
            rocmGpuTargets = [ "gfx1151" ];
            rocmPackages =
              if llamaCppRocm10 then
                rocm10Pkgs.rocmPackages_10.gfx1151
              else
                prev.rocmPackages;
          }
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
            cmakeFlags =
              (prevAttrs.cmakeFlags or [ ])
              ++ [
                "-DLLAMA_BUILD_UI=OFF"
              ]
              ++ lib.optionals llamaCppRocm10 [
                "-DCMAKE_HIP_FLAGS=--rocm-path=${rocm10Pkgs.rocmPackages_10.gfx1151.clr}"
              ];

            disabledTests = (prevAttrs.disabledTests or [ ]) ++ [
              "test-conversion-fp8"
            ];
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
        11434
        11436
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

  systemd.services.comfyui-image-build = {
    description = "Build ${comfyuiImage} for the current ComfyUI pin";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = comfyuiImageBuild;
      TimeoutStartSec = 3600;
    };
  };

  systemd.services.podman-comfyui.serviceConfig.ExecStartPre = lib.mkAfter [
    "+${comfyuiImageBuild}"
  ];

  services.llama-cpp = lib.optionalAttrs (!llamacppPerInstance) {
    enable = true;
    package = pkgs.llama-cpp-rocm;
    settings = {
      models-preset = "${llamacppIni}";
      host = "127.0.0.1";
      port = llamaRouterPort;
    };
  };


  systemd.services.llama-decision = {
    description = "llama.cpp: vllm-d3-nano decision model (always on, /v1/systemone)";
    after = [ "network.target" ];
    wants = [ "network.target" ];
    unitConfig.ConditionPathExists = decisionGguf;
    startLimitIntervalSec = 300;
    startLimitBurst = 3;
    serviceConfig = {
      Type = "simple";
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

      Environment = [ "GPU_MAX_HW_QUEUES=1" ];

      KillSignal = "SIGTERM";
      TimeoutStopSec = 60;
      Restart = "on-failure";
      RestartSec = 5;
      LimitMEMLOCK = "infinity";
      NoNewPrivileges = true;
      PrivateTmp = true;

      OOMScoreAdjust = 800;
      MemoryHigh = "4G";
      MemoryMax = "4.5G";
      IPAddressAllow = [
        "127.0.0.0/8"
        "::1/128"
        "192.168.0.0/24"
      ];
      IPAddressDeny = "any";
    };
    wantedBy = [ "multi-user.target" ];
  };

  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
  };
  users.groups.llama-swap = { };

  services.llama-swap = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 11434;

    settings = {
      healthCheckTimeout = 900;
      logLevel = "info";

      models =
        let
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
        }
        // builtins.listToAttrs (map (n: {
          name = n;
          value = presetRow n llamacppPresets.${n};
        }) llamacppPresetNames)
        // {
          "${comfyuiModelId}" = {
            name = "ComfyUI";
            cmd = swapUnitHolder "podman-comfyui.service";

           cmdStop = "systemctl stop podman-comfyui.service";

            unloadTimeout = 60;

            proxy = "http://127.0.0.1:${toString comfyuiPort}";
            checkEndpoint = "/system_stats";

          };
        }
        // lib.optionalAttrs qwenImageEnabled {
          "qwen-image-2.1" = {
            name = "Qwen-Image-2.1";
            cmd = swapUnitHolder "gufo-image.service";
            proxy = "http://127.0.0.1:${toString gufoImagePort}";
            checkEndpoint = "/health";
          };
        };

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
              members = llamacppPresetNames ++ [ comfyuiModelId ]
              ++ lib.optionals qwenImageEnabled [ "qwen-image-2.1" ];
            };
          };
        };

      routing.scheduler = {
        use = "fifo";
        settings.fifo.priority = {
          "${gufoServedName}" = 10;
        };
      };
    };
  };

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
    LimitMEMLOCK = "infinity";
  };


  users.users.gufo = {
    isSystemUser = true;
    group = "gufo";
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
    startLimitIntervalSec = 300;
    startLimitBurst = 3;
    unitConfig = {
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
      KillSignal = "SIGTERM";
      TimeoutStopSec = 120;
      Restart = "on-failure";
      RestartSec = 5;
      LimitMEMLOCK = "infinity";
      NoNewPrivileges = true;
      PrivateTmp = true;

      OOMScoreAdjust = -500;
      MemoryLow = "64G";

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
          --host 127.0.0.1 --port ${toString gufoImagePort} \
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

  modules.alloy = {
    enable = true;

    pushUrl = "http://192.168.0.203:9090/api/v1/write";

    allowedNetworks = [
      "127.0.0.0/8"
      "::1/128"
      "192.168.0.0/24"
    ];

    nodeExporter = {
      enable = true;
      scrapeInterval = "10s";
      scrapeTimeout = "5s";
    };

    selfScrape = true;
    selfScrapeInterval = "30s";

    textfile = {
      interval = "10s";
      amdgpu.enable = true;
      comfyui = {
        enable = true;
        url = "http://127.0.0.1:${toString comfyuiPort}";
      };
      llamacpp = {
        enable = !llamacppPerInstance;
        url = "http://127.0.0.1:${toString llamaRouterPort}";
        configIni = "${llamacppIni}";
        probeModels = false;
      };
    };

    jobs = [
      {
        name = "gufo";
        description = "gufo: /metrics on the LLM unit (loopback). Down == that engine is not loaded.";
        targets = [
          {
            addr = "127.0.0.1:${toString gufoLlmPort}";
            labels = { service = "gufo-llm.service"; };
          }
        ];
        scrapeInterval = "5s";
        scrapeTimeout = "4s";
      }
      {
        name = "llama-swap";
        description = "llama-swap: always on, host counters of the serving path (llamaswap_*).";
        targets = [
          { addr = "127.0.0.1:${toString llamaSwapPort}"; }
        ];
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
