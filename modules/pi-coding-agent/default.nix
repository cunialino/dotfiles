{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.pi-coding-agent;

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
        model = "llhalo/ornith-1.5-35b";
        packages = [
          "npm:pi-mcp-adapter"
        ];
      };
      models = {
        providers = {
          # Two ways to reach a model on this box, both plain OpenAI-compatible
          # servers with no key:
          #
          #   11434  llama.cpp -- now a native nixpkgs ROCm service instead of a
          #          container. The address is unchanged, so nothing here needed to
          #          move; it runs in router mode, where the requested model name
          #          selects the preset from /var/lib/llama-models/config.ini.
          #   8731   the halogen container, which is still the only thing serving
          #          Qwen3.8 Flash-Next at this point.
          #
          # strixhalocpp and llhalo both point at 11434 with different model lists.
          # Redundant, but harmless while both resolve to the same server.
          "halogen" = {
            baseUrl = "http://192.168.0.6:8731/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              {
                id = "halogen-qwen3.8-flash-next";
                contextWindow = 262144;
                input = [ "text" "image" ];
              }
            ];
          };
          "strixhalocpp" = {
            baseUrl = "http://192.168.0.6:11434/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              { id = "gpt-oss-120b-MXFP4"; contextWindow = 131072; }
            ];
          };
          "llhalo" = {
            baseUrl = "http://192.168.0.6:11434/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              { id = "glm-4.5-air"; contextWindow = 131072; }
              {
                id = "ornith-1.5-35b";
                contextWindow = 262144;
                input = [ "text" "image" ];
              }
              {
                id = "qwen3.6";
                contextWindow = 262144;
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
