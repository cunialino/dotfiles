{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.modules.alloy;
  types = lib.types;

  # Everything that goes into the River config is a hostname, a port, a job name
  # or a label value. River string literals get no escaping layer here, so a
  # value that would need one is a mistake in the module rather than something
  # to paper over: fail the eval with the offending value instead of emitting a
  # config that parses differently than it was written.
  safe = kind: v:
    let
      s = toString v;
    in
    if builtins.match "[A-Za-z0-9_.:+/@ -]*" s != null then
      s
    else
      builtins.throw "modules.alloy: ${kind} ${lib.strings.escapeNixString s} cannot go into the Alloy config";

  # The config is assembled from a list of lines, tab-indented the way
  # `alloy fmt` writes (verified with `alloy validate` / `alloy fmt` from
  # nixpkgs' grafana-alloy: validation passes; fmt still differs on bracket
  # spacing and on how it aligns `targets` with the longest attribute name, which
  # is cosmetic and not worth reproducing here). And not from ''...'' literals:
  # an indented string drops the indentation of a single-line literal along with
  # the column its closing delimiter sits at, and re-indents interpolated
  # multi-line values -- which mangles the output invisibly. Double-quoted
  # strings do what they say.
  kv = k: v: "\"${safe "label name" k}\" = \"${safe "label value" v}\"";

  # One line of a target list:
  #     { "__address__" = "127.0.0.1:8732", "service" = "gufo-llm.service" },
  renderTarget = t:
    let
      labels = {
        "__address__" = safe "target address" t.addr;
      } // t.labels;
    in
    "\t{ " + lib.concatStringsSep ", " (lib.mapAttrsToList kv labels) + " },";

  # An Alloy component label has to be an identifier; the Prometheus job name is
  # an ordinary label value and keeps its dashes. So the job "llama-swap" is
  # scraped by the component prometheus.scrape.llama_swap.
  componentLabel = builtins.replaceStrings [ "-" "." ] [ "_" "_" ];

  renderJob = job:
    lib.optionals (job.description != "") (
      map (line: "// " + line) (lib.splitString "\n" (lib.removeSuffix "\n" job.description))
    )
    ++ [
      "prometheus.scrape \"${componentLabel job.name}\" {"
      "\tjob_name        = \"${safe "job name" job.name}\""
      "\tscrape_interval = \"${safe "scrape interval" job.scrapeInterval}\""
      "\tscrape_timeout  = \"${safe "scrape timeout" job.scrapeTimeout}\""
      "\ttargets = ["
    ]
    ++ map renderTarget job.targets
    ++ [
      "\t]"
      "\tforward_to = [ prometheus.remote_write.push.receiver ]"
      "}"
      ""
    ];

  # What is worth having on a box whose whole job is serving models: cpu, the
  # memory accounting (meminfo/vmstat/pressure -- on a unified-memory machine
  # "how much is left" IS the question), disk, net, uptime, and the textfile dir
  # the amdgpu/ComfyUI collector writes. Deliberately absent:
  #   * drm      -- a second, differently-named view of the same vram/gtt
  #                counters the amdgpu collector already reports;
  #   * systemd  -- unit-state metrics need a private dbus connection, which
  #                services.alloy's DynamicUser does not get. `up{job=...}` on
  #                each backend answers "is it loaded" anyway;
  #   * node_exporter's other default sets (arp, bcache, conntrack, edac,
  #     infiniband, nfs, ...) -- nothing here reads them.
  nodeCollectors = [
    "cpu"
    "cpufreq"
    "diskstats"
    "filesystem"
    "hwmon"
    "loadavg"
    "meminfo"
    "netclass"
    "netdev"
    "pressure"
    "stat"
    "textfile"
    "time"
    "uname"
    "vmstat"
  ];

  textfileDir = "/run/alloy/textfile";

  substitute = text: pairs: lib.replaceStrings (map (p: p.var) pairs) (map (p: p.val) pairs) text;

  textfileFragments =
    lib.optionals cfg.textfile.amdgpu.enable [
      (substitute (builtins.readFile ./amdgpu-metrics.sh) [
        {
          var = "@CARD_DIR@";
          val = "/sys/class/drm/${cfg.textfile.amdgpu.card}/device";
        }
        {
          var = "@CARD@";
          val = cfg.textfile.amdgpu.card;
        }
      ])
    ]
    ++ lib.optionals cfg.textfile.comfyui.enable [
      (substitute (builtins.readFile ./comfyui-metrics.sh) [
        {
          var = "@COMFY_URL@";
          val = cfg.textfile.comfyui.url;
        }
      ])
    ]
    ++ lib.optionals cfg.textfile.llamacpp.enable [
      (substitute (builtins.readFile ./llamacpp-metrics.sh) [
        {
          var = "@ROUTER_URL@";
          val = cfg.textfile.llamacpp.url;
        }
        {
          var = "@CONFIG_INI@";
          val = cfg.textfile.llamacpp.configIni;
        }
        {
          var = "@PROBE_MODELS@";
          val = if cfg.textfile.llamacpp.probeModels then "true" else "false";
        }
      ])
    ];

  # What the collector fragments shell out to. amdgpu_top only when the amdgpu
  # fragment is in there: it is the one package of the set that is not on every
  # machine this module could be enabled on.
  textfileDeps =
    [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.jq
      pkgs.curl
    ]
    ++ lib.optionals cfg.textfile.amdgpu.enable [ pkgs.amdgpu_top ];

  textfileCollector = pkgs.writeShellScript "alloy-textfile-collect" ''
    # Writes the *.prom files that prometheus.exporter.unix's textfile collector
    # picks up. See sys_mods/alloy for the metric list.
    #
    # No `set -e` on purpose: a source that is down (ComfyUI not running,
    # amdgpu_top cannot open the render node) must still leave a complete file
    # behind -- the counters that ARE readable plus an explicit `*_up 0` --
    # instead of failing the unit and leaving yesterday's numbers in place.
    set -uo pipefail

    export PATH=${lib.makeBinPath textfileDeps}

    out_dir=${textfileDir}
    mkdir -p "$out_dir"

    ${lib.concatStringsSep "\n" textfileFragments}
  '';

  anyTextfile = cfg.textfile.amdgpu.enable || cfg.textfile.comfyui.enable || cfg.textfile.llamacpp.enable;

  # A scrape is a request, and a request to a lazily-loaded backend is what
  # loads it. llama.cpp's router answers GET /metrics by proxying it to the
  # instance named by ?model=, through the same queue as a chat completion
  # (join -> ensure_model -> spawn): the scrape boots the preset, and models-max
  # then evicts whatever was resident for it. See llamacpp-metrics.sh, which
  # reads residency out of /proc instead of asking.
  #
  # The module could not know this on its own -- __param_<name> labels are a
  # legitimate thing to want in general -- but a job that carries this one is
  # always the same mistake, so fail the eval rather than rediscover it in the
  # serving path at 3 a.m.
  #
  # It stays in place even for a host that runs one llama-server per preset
  # (hosts/strix_halo, llamacppPerInstance), where the scrape lands on the
  # instance itself and __param_model would be inert: the assertion costs nothing
  # and the router is one config line away.
  modelParamTargets =
    builtins.concatMap (
      job:
      builtins.concatMap (
        t:
        lib.optionals (t.labels ? "__param_model") [ "${job.name} -> ${t.addr}" ]
      ) job.targets
    ) cfg.jobs;
in
{
  options.modules.alloy = {
    enable = lib.mkEnableOption "Grafana Alloy, pushing metrics to Prometheus over remote_write";

    package = lib.mkPackageOption pkgs "grafana-alloy" { };

    pushUrl = lib.mkOption {
      type = types.str;
      default = "";
      description = ''
        Prometheus remote_write endpoint: the full /api/v1/write URL of a
        Prometheus started with --web.enable-remote-write-receiver. Empty runs
        Alloy with no destination, which is only useful while bringing the
        receiving side up.
      '';
    };

    externalLabels = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Extra labels on every pushed series, on top of `instance` (set to the
        hostname, which is what the cluster's Prometheus and its dashboards key
        on). Per-target detail is NOT carried by instance -- it is the same value
        for everything this box pushes -- so every target with siblings in a job
        brings its own label (`service`, `preset`).
      '';
    };

    listenAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1:12345";
      description = "Alloy's own UI/API (and /metrics) listen address.";
    };

    allowedNetworks = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "127.0.0.0/8"
        "::1/128"
      ];
      description = ''
        Networks the alloy unit may talk to (and be talked to from), applied as
        systemd's IPAddressAllow. The push destination must be inside this set:
        a monitoring agent answers, it does not call home, and everything else
        is denied by IPAddressDeny.
      '';
    };

    jobs = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = lib.mkOption {
            type = types.str;
            description = "Prometheus job name; the Alloy component label is this with dashes replaced.";
          };

          description = lib.mkOption {
            type = types.str;
            default = "";
            description = "Comment rendered above the job (each line gets its own //).";
          };

          scrapeInterval = lib.mkOption {
            type = types.str;
            default = "15s";
          };

          scrapeTimeout = lib.mkOption {
            type = types.str;
            default = "10s";
            description = ''
              Keep it below scrapeInterval. A backend that is mid-request on a
              single-worker server (llama.cpp, gufo) can answer slowly without
              being down, and timeouts that overlap the next scrape turn that
              into a backlog of useless samples.
            '';
          };

          targets = lib.mkOption {
            type = types.listOf (types.submodule {
              options = {
                addr = lib.mkOption {
                  type = types.str;
                  description = "host:port";
                };
                labels = lib.mkOption {
                  type = types.attrsOf types.str;
                  default = { };
                  description = ''
                    Labels on this target. `__param_<name>` becomes a query
                    parameter of the scrape request. Note that `__param_model`
                    is refused: against a router that lazy-loads by model name it
                    is not a selector but a request for that model, and it will
                    be loaded to answer.
                  '';
                };
              };
            });
            default = [ ];
          };
        };
      });
      default = [ ];
      description = "Local scrape jobs.";
    };

    nodeExporter = {
      enable = lib.mkEnableOption "node metrics through Alloy's built-in unix exporter";

      scrapeInterval = lib.mkOption {
        type = types.str;
        default = "15s";
        description = ''
          Interval for the node job. One knob buys two different things, and the
          ceiling is not the same for both: cpu/pressure/meminfo get genuinely
          finer, while textfile metrics (amdgpu, ComfyUI) are only as fresh as
          alloy-textfile-collect.timer, so scraping below that interval ships the
          same number again rather than a newer one.
        '';
      };

      scrapeTimeout = lib.mkOption {
        type = types.str;
        default = "10s";
        description = "Keep below scrapeInterval.";
      };
    };

    selfScrape = lib.mkEnableOption "scraping Alloy's own metrics";

    selfScrapeInterval = lib.mkOption {
      type = types.str;
      default = "30s";
      description = ''
        Interval for Alloy's own metrics. Worth leaving slow: it is 749 series of
        pipeline internals (component health, WAL depth, remote_write counters)
        whose useful movement is minutes, and tripling it is the single most
        expensive scrape on the box -- the remote_write counters that answer "is
        the push landing?" cannot miss anything at 30 s.
      '';
    };

    textfile = {
      amdgpu = {
        enable = lib.mkEnableOption ''
          the amdgpu textfile collector (memory totals, per-IP activity and
          per-process GPU memory through amdgpu_top)
        '';

        card = lib.mkOption {
          type = types.str;
          default = "card0";
          description = "DRM card to report.";
        };
      };

      comfyui = {
        enable = lib.mkEnableOption "the ComfyUI textfile collector";

        url = lib.mkOption {
          type = types.str;
          default = "http://127.0.0.1:8188";
          description = "ComfyUI base URL. It has no /metrics; this reads /system_stats and /prompt.";
        };
      };

      llamacpp = {
        enable = lib.mkEnableOption ''
          the llama.cpp router textfile collector (preset residency from the
          process table and the router's own preset file, with no request to the
          router itself)
        '';

        url = lib.mkOption {
          type = types.str;
          default = "http://127.0.0.1:11435";
          description = ''
            Base URL of the llama.cpp router. Used only by the probeModels
            request; everything else this collector reports comes from /proc and
            configIni.
          '';
        };

        configIni = lib.mkOption {
          type = types.str;
          default = "";
          description = ''
            Path of the file behind the router's --models-preset, whose
            [sections] are the preset list. Required when enabled: it is both
            the preset list and what identifies the router process.
          '';
        };

        probeModels = lib.mkOption {
          type = types.bool;
          default = false;
          description = ''
            Also GET /v1/models (falling back to /models) on the router and
            report whether it answered and how many instances it lists.

            Off by default. The instance list belongs to the management family
            (/models/load, /models/unload, /models/sse) and is answered by the
            router rather than proxied, which is what makes it safe to ask --
            but that is a reading of the route table, not a measurement. Turn it
            on only after the first interval shows no "join: request" line in the
            router's log.
          '';
        };
      };

      interval = lib.mkOption {
        type = types.str;
        default = "10s";
        description = "How often the textfile collectors rewrite their files.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = modelParamTargets == [ ];
        message = "modules.alloy: ${lib.concatStringsSep ", " modelParamTargets} sets the __param_model label. Scraping the llama.cpp router with ?model= LOADS that preset -- /metrics is proxied through the request queue -- so the job would cycle every preset it names. Use the textfile.llamacpp collector and query llamacpp_preset_loaded instead.";
      }
      {
        assertion = !(cfg.textfile.llamacpp.enable && cfg.textfile.llamacpp.configIni == "");
        message = "modules.alloy: textfile.llamacpp.configIni is required when the collector is enabled. Its [sections] are the preset list and its path is what identifies the router process; with neither, every preset would report 0 and read as an idle box.";
      }
    ];

    environment.etc."alloy/config.alloy".text =
      let
        labels = {
          instance = config.networking.hostName;
        } // cfg.externalLabels;
      in
      lib.concatStringsSep "\n" (
        [
          "// Generated by NixOS (sys_mods/alloy). Edit the module, not this file."
          ""
          "prometheus.remote_write \"push\" {"
          "\texternal_labels = {"
        ]
        ++ lib.mapAttrsToList (k: v: "\t\t\"${safe "external label name" k}\" = \"${safe "external label value" v}\",") labels
        ++ [
          "\t}"
          ""
          "\tendpoint {"
          "\t\turl            = \"${safe "pushUrl" cfg.pushUrl}\""
          "\t\tname           = \"k3s\""
          # Shorter than the 30 s default: a Prometheus that is being replaced is
          # unreachable rather than slow, and sitting inside a dead request only
          # delays the retry that follows it.
          "\t\tremote_timeout = \"20s\""
          "\t}"
          "}"
          ""
        ]
        ++ lib.optionals cfg.nodeExporter.enable [
          "prometheus.exporter.unix \"node\" {"
          "\tset_collectors = ["
        ]
        ++ map (c: "\t\t\"${c}\",") nodeCollectors
        ++ [
          "\t]"
          ""
          "\ttextfile {"
          "\t\tdirectory = \"${textfileDir}\""
          "\t}"
          "}"
          ""
          "prometheus.scrape \"node\" {"
          "\tjob_name        = \"node\""
          "\tscrape_interval = \"${safe "node scrapeInterval" cfg.nodeExporter.scrapeInterval}\""
          "\tscrape_timeout  = \"${safe "node scrapeTimeout" cfg.nodeExporter.scrapeTimeout}\""
          "\ttargets         = prometheus.exporter.unix.node.targets"
          "\tforward_to      = [ prometheus.remote_write.push.receiver ]"
          "}"
          ""
        ]
        ++ lib.optionals cfg.selfScrape [
          "// Alloy's own pipeline: prometheus_remote_storage_* says whether the"
          "// push is landing, alloy_component_* whether any component went unhealthy."
          "prometheus.scrape \"alloy\" {"
          "\tjob_name        = \"alloy\""
          "\tscrape_interval = \"${safe "selfScrapeInterval" cfg.selfScrapeInterval}\""
          "\ttargets = ["
          "\t\t{ \"__address__\" = \"${safe "listenAddress" cfg.listenAddress}\" },"
          "\t]"
          "\tforward_to = [ prometheus.remote_write.push.receiver ]"
          "}"
          ""
        ]
        ++ lib.concatMap renderJob cfg.jobs
      );

    services.alloy = {
      enable = true;
      package = cfg.package;

      # No phone home to Grafana, and the UI stays on loopback.
      extraFlags = [
        "--disable-reporting"
        "--server.http.listen-addr=${cfg.listenAddress}"
      ];
    };

    # Scrape loopback, push to the allowed networks, nothing else: the same rule
    # the gufo units follow. systemd's IPFilter is cgroup-scoped and filters
    # inbound as well as outbound, so the LAN has to be listed for the push to
    # leave at all.
    systemd.services.alloy.serviceConfig = {
      IPAddressAllow = cfg.allowedNetworks;
      IPAddressDeny = "any";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = "read-only";
    };

    systemd.tmpfiles.rules = lib.optionals anyTextfile [
      # 0755, not 0700: the unix exporter runs as alloy's DynamicUser and has to
      # read what these collectors write.
      "d ${textfileDir} 0755 root root -"
    ];

    systemd.services.alloy-textfile-collect = lib.mkIf anyTextfile {
      description = "Write amdgpu/ComfyUI metrics for Alloy's textfile collector";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = textfileCollector;
        # Root for two things: /proc/<pid>/fdinfo of other users' processes --
        # that is where amdgpu_top reads per-process GTT from, and unprivileged
        # it sees only its own (so gufo, i.e. nearly everything, is invisible) --
        # and the render node for the GRBM activity counters.
      };
    };

    systemd.timers.alloy-textfile-collect = lib.mkIf anyTextfile {
      description = "Periodic amdgpu/ComfyUI textfile rewrite";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10s";
        OnUnitActiveSec = cfg.textfile.interval;
        AccuracySec = "1s";
      };
    };
  };
}
