{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.opencode;
in
{
  options.modules.opencode.enable = lib.mkEnableOption "opencode";
  config = lib.mkIf cfg.enable {
    programs.mcp = {
      enable = true;
      servers = {
        k8s-fetch = {
          type = "sse";
          url = "https://mcpo.tail2f38ea.ts.net/fetch/sse";
        };
        k8s-search = {
          type = "sse";
          url = "https://mcpo.tail2f38ea.ts.net/ddg-search/sse";
        };
        k8s-memory = {
          type = "sse";
          url = "https://mcpo.tail2f38ea.ts.net/memory/sse";
        };
      };
    };
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      agents = ./agents;
      settings = {
        "$schema" = "https://opencode.ai/config.json";

        provider = {
          "local-780m" = {
            npm = "@ai-sdk/openai-compatible";
            name = "Local 780M iGPU";
            options = {
              baseURL = "https://genai.tail2f38ea.ts.net/v1";
              apiKey = "not-needed";
            };
            models = {
              "gemma4" = {
                name = "gemma4";
              };
              "qwen3.6" = {
                name = "qwen3.6";
              };
            };
          };
        };
        model = "local-780m/qwen3-coder-30b-a3b";
      };
    };
  };
}
