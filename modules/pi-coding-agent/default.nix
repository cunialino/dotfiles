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
          "local-780m" = {
            baseUrl = "https://genai.tail2f38ea.ts.net/v1";
            apiKey = "not-needed";
            api = "openai-completions";
            models = [
              { id = "gemma4"; }
              { id = "gemma4-heretic"; }
              { id = "gemma4-uc"; }
              { id = "qwen3.8_27B"; }
              { id = "qwen3.6"; }
            ];
          };
        };
      };
      context = ./instructions/system.md;
    };
  };
}
