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
          "halogen" = {
            baseUrl = "http://192.168.0.6:8731/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              { id = "halogen-qwen3.8-flash-next"; contextWindow = 262144; }
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
              { id = "ornith-1.5-35b"; contextWindow = 262144; }
              { id = "qwen3.6"; contextWindow = 262144; }
            ];
          };
        };
      };
      context = ./instructions/system.md;
    };
  };
}
