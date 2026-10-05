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
  };
}
