{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.pi-coding-agent;

  jsonFormat = pkgs.formats.json { };

  # llama-swap model ID for the gufo Qwen3.8 Flash-Next unit (a real entry, not an
  # alias -- aliases get no display name of their own and clutter /v1/models). The
  # agent talks to the swap only; the swap decides which backend answers and
  # unloads the others.
  gufoModelName = "qwen3.8-flash-next";

  # The guard is a single-file Pi extension whose settings are baked in at build
  # time: herdr and civetta start pi without the environment a shell would carry,
  # and a `PI_GUARD_*` override still works for one session because the generated
  # file reads them as `process.env.X ?? <configured value>`.
  commandGuardExtension = pkgs.replaceVars ./command-guard.ts {
    endpoint = cfg.commandGuard.endpoint;
    model = cfg.commandGuard.model;
    threshold = toString cfg.commandGuard.threshold;
    mode = cfg.commandGuard.mode;
    timeoutMs = toString cfg.commandGuard.timeoutMs;
    tools = builtins.toJSON cfg.commandGuard.tools;
  };

in
{
  options.modules.pi-coding-agent = {
    enable = lib.mkEnableOption "pi-coding-agent";

    mcpToolExposure = lib.mkOption {
      type = jsonFormat.type;
      default = {
        # Graphiti is the only configured server that can erase its own contents.
        # Reading and writing memories is what the agent is here for; dropping
        # episodes, edges or the whole graph is one careless tool call away from
        # being unrecoverable, so those stay out of the model's reach.
        graphiti = {
          "delete_*" = "hidden";
          "clear_graph" = "hidden";
        };
      };
      example = lib.literalExpression ''
        {
          graphiti = {
            "delete_*" = "hidden";
            "clear_graph" = "hidden";
          };
        }
      '';
      description = ''
        Per-server `toolExposure` maps for Pi's built-in MCP client, keyed by
        server name and written to {file}`~/.pi/agent/mcp.json` alongside the
        entries generated from {option}`modules.mcp.servers`. Keys are exact
        server tool names or patterns, values are `direct`, `deferred`,
        `codemode` or `hidden`; see
        <https://pi.dev/docs/latest/mcp> ("Control tool exposure").
      '';
    };

    commandGuard = {
      enable = lib.mkEnableOption ''
        the Pi command guard, which asks a decision model whether a command is
        dangerous before it runs
      '';

      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://192.168.0.6:11436/v1/systemone";
        description = ''
          System One classifier endpoint: `POST`, questions in the `choice`,
          `score` and `noul` shapes Pi speaks natively. It sits next to the swap
          on the same box as the provider baseUrl above, and deliberately not
          behind it -- the swap answers chat completions only and returns 404 for
          this route.
        '';
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "d3-nano";
        description = ''
          Model id served at {option}`endpoint`. The guard registers it with Pi as
          the classifier model `decision/<id>` -- also what a `codemode` script
          sees under `models.getAvailableOfType("classifier")`. Classifier models
          never appear in `/model`, so this cannot become the agent model by
          accident.
        '';
      };

      threshold = lib.mkOption {
        type = lib.types.addCheck lib.types.number (value: value >= 0 && value <= 1);
        default = 0.5;
        description = ''
          Probability of damage at which a call needs approval. Measured on
          d3-nano with the guard's own question: `cargo test --release` 0.01,
          `echo hi` 0.05, `git push --force origin main` 0.69, `rm -rf ~` 0.99.
          The reading is soft rather than parsed -- an `rm -rf` of a path that
          looks disposable scored 0.45 -- so this trades false prompts against
          misses instead of eliminating either.
        '';
      };

      mode = lib.mkOption {
        type = lib.types.enum [ "observe" "confirm" "block" ];
        default = "observe";
        description = ''
          What a dangerous verdict costs the run. `observe` records it and lets the
          command through; `confirm` asks the user, and blocks where there is no UI
          to ask with -- which is every herdr and civetta run; `block` refuses
          without asking.

          Every judged command lands in
          {file}`~/.pi/agent/command-guard.log` whatever the mode, with `allow`,
          `block` or `would-block` -- the last being what `observe` let past. That
          file is the promotion path: read a day of real work there, then switch.
          `jq -r 'select(.action != "allow") | [.danger, .command] | @tsv'` is the
          whole review.
        '';
      };

      timeoutMs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5000;
        description = ''
          Deadline for one classification, measured at 50-250ms on the Strix
          Halo. Judging a command therefore costs nothing visible; the deadline
          is for a server that is down rather than slow, and a command with no
          answer counts as dangerous -- that is what separates a guard from a
          decoration.
        '';
      };

      tools = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ "bash" "powershell" ];
        example = [ "bash" "edit" "write" ];
        description = ''
          Tool calls the guard judges. Only tools that carry their action in a
          `command` argument can be judged by the guard's question, so `edit` and
          `write` would need a question of their own first. Commands the user
          types with `!` never reach `tool_call` and are not gated.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi-coding-agent = {
      enable = true;

      settings = {
        # pi 1.0 resolves the startup model from defaultProvider + defaultModel.
        # A bare `model` key is neither a current setting nor one of the migrated
        # legacy keys, so it is ignored and the startup model becomes "first
        # available" -- here that means whichever entry happens to lead the
        # llhalo.models list.
        defaultProvider = "llhalo";
        defaultModel = gufoModelName;
      };
      models = {
        providers = {
          # Everything the agent reaches goes through llama-swap on 11434: the swap
          # picks the backend, unloads the others, and is the only served port.
          #
          # The ids, context windows and vision flags mirror the live config rather
          # than aspiration -- llama-swap /v1/models for the ids, the ctx-size and
          # mmproj lines in /var/lib/llama-models/config.ini for the router presets,
          # and gufo's own `context_tokens=262144` load line for the agent model.
          # A contextWindow that is too big makes pi send prompts the server
          # rejects; too small and it truncates its own history for no reason.
          #
          # halogen is gone. It was the pre-gufo backend and its container is no
          # longer on the host config; the 126 GB of weights stay on disk for a
          # hand-started rescue (see hosts/strix_halo/default.nix), which is not
          # something pi should ever point at by default.
          "llhalo" = {
            baseUrl = "http://192.168.0.6:11434/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              # gufo (port 8732 behind the swap) -- the default, see settings.model
              {
                id = gufoModelName;
                contextWindow = 262144;
                input = [ "text" "image" ]; # mmproj-BF16.gguf
                # pi sends max_tokens from this field and falls back to 16384 when it is
                # absent (core/provider-composer.js). That default is a trap for agentic
                # work: 16k output tokens is not much once a model writes whole files, and
                # a response cut off in the middle lands nothing at all -- pi shows
                # "Response was truncated before completion", herdr still reports `done`,
                # and the run is simply lost (measured: three attempts, zero files).
                # The queue rations turns on one inference unit, so make the cap generous
                # rather than polite; the agent model is the only one that writes files.
                maxTokens = 32768;
              }

              # llama.cpp router presets (port 11435 behind the swap)
              {
                id = "qwen3.6";
                contextWindow = 262144;
                input = [ "text" "image" ];
              }
              {
                id = "ornith-1.5-35b";
                contextWindow = 262144;
                input = [ "text" "image" ];
              }
              {
                id = "ornith-og";
                contextWindow = 262144;
                input = [ "text" "image" ];
              }
              {
                id = "ori";
                contextWindow = 262144;
              }
              {
                id = "glm-4.5-air";
                contextWindow = 131072;
              }
              {
                id = "deepseek-ocr";
                contextWindow = 16384;
                input = [ "text" "image" ];
              }
            ];
          };
        };
      };
      context = ./instructions/system.md;
    };

    # pi >= 0.99 speaks MCP on its own, so the shared server list is handed to it
    # directly. npm:pi-mcp-adapter used to stand in for this and would now do worse
    # than nothing: an extension that registers /mcp replaces the built-in support,
    # which means pi stops reading mcp.json at all and these servers disappear from
    # `pi mcp list`, from /mcp and from the exposure control below.
    #
    # exposure = "direct" declares each tool to the model like a built-in tool.
    # pi's own default is "codemode", i.e. reachable only from codemode scripts,
    # which is not enabled here.
    home.file.".pi/agent/mcp.json" = lib.mkIf (config.modules.mcp.servers != { }) {
      source = jsonFormat.generate "pi-mcp.json" {
        mcpServers = lib.mapAttrs (
          name: server:
          let
            toolExposure = cfg.mcpToolExposure.${name} or { };
          in
          {
            exposure = "direct";
          }
          // lib.optionalAttrs (server.url != null) {
            type = "http";
            url = server.url;
          }
          // lib.optionalAttrs (server.command != null) {
            command = server.command;
            inherit (server) args;
          }
          // lib.optionalAttrs (toolExposure != { }) { inherit toolExposure; }
        ) config.modules.mcp.servers;
      };
    };

    # Pi discovers plain `.ts` files in `extensions/` and jiti compiles them in
    # process, so a read-only store path is the whole installation. The guard
    # registers its classifier itself through `pi.registerProvider`, which is why
    # none of this appears in `programs.pi-coding-agent.models`.
    home.file.".pi/agent/extensions/command-guard.ts" = lib.mkIf cfg.commandGuard.enable {
      source = commandGuardExtension;
    };
  };
}
