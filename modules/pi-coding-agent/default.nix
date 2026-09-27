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
          # 8731 is halogen, reached directly. It bypasses llama-swap on purpose:
          # at this point it is the only thing serving Qwen3.8 Flash-Next, and it
          # is not a swap model.
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

          # 11434 is llama-swap, and it is now the ONLY thing listening there --
          # llama.cpp moved to 127.0.0.1:11435 behind it. That makes this provider
          # the single entry point for everything the swap knows about: the ids
          # below are the router aliases llama-swap advertises (includeAliasesInList
          # = true), and asking for one starts llama.cpp through a holder unit. The
          # agent and genai groups are exclusive, so a request here can unload
          # whatever the other group was holding -- which is the point, 124 GiB of
          # unified memory does not fit two of them.
          #
          # The old "strixhalocpp" provider is gone with this: same baseUrl, and its
          # only model (gpt-oss-120b-MXFP4) is not in the router preset tree any
          # more, so it could only ever 404.
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
