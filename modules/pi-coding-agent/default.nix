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
        model = "local-780m/qwen3-coder-30b-a3b";
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
              { id = "halogen-qwen3.8-flash-next"; }
            ];
          };
          "strixhalocpp" = {
            baseUrl = "http://192.168.0.6:11434/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              { id = "gpt-oss-120b-MXFP4"; }
            ];
          };
          "llhalo" = {
            baseUrl = "http://192.168.0.6:11434/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              { id = "glm-4.5-air"; }
              { id = "ornith-1.5-35b"; }
              { id = "qwen3.6"; }
            ];
          };
        };
      };
      context = ./instructions/system.md;
    };
  };
}
