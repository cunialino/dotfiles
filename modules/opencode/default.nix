{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.opencode;

in
{
  options.modules.opencode.enable = lib.mkEnableOption "opencode";
  config = lib.mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      agents = ./agents;
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        instructions = [ ./instructions/system.md ];

        provider = {
          "halogen" = {
            npm = "@ai-sdk/openai-compatible";
            name = "HaloGen Strix Server";
            options = {
              baseURL = "http://192.168.0.6/v1";
              apiKey = "not-needed";
            };
            models = {
              "halogen-qwen3.8-flash-next" = {
                name = "halogen-qwen3.8-flash-next";
              };
            };
          };
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
              "gemma4-heretic" = {
                name = "gemma4-heretic";
              };
              "gemma4-uc" = {
                name = "gemma4-uc";
              };
              "qwen3.8_27B" = {
                name = "qwen3.8_27B";
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
