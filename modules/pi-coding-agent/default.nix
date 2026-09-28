{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.pi-coding-agent;

  # llama-swap's alias for the gufo Qwen3.8 Flash-Next unit. The agent talks to
  # the swap only; the swap decides which backend answers and unloads the others.
  gufoModelName = "qwen3.8-flash-next";

in
{
  options.modules.pi-coding-agent.enable = lib.mkEnableOption "pi-coding-agent";

  config = lib.mkIf cfg.enable {
    programs.pi-coding-agent = {
      enable = true;
      extraPackages = [
        pkgs.nodejs # provides npm and npx
      ];

      settings = {
        model = "llhalo/${gufoModelName}";
        packages = [
          "npm:pi-mcp-adapter"
        ];
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
  };
}
