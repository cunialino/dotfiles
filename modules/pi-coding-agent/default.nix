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
          # RESCUE PATH ONLY. 8731 is still halogen's container port (gufo took
          # 8732 so the two never collide). Delete this provider once gufo has
          # proven itself and the halogen container is gone from the host config.
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
              {
                id = gufoModelName;
                contextWindow = 262144;
                input = [ "text" "image" ];
              }
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
