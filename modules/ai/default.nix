{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.ai;
  llm-functions = pkgs.fetchFromGitHub {
    owner = "sigoden";
    repo = "llm-functions";
    rev = "main";
    hash = "sha256-CjuwlmTjTMqptYOMVghTpcauK2rBrvgkUR9IqZuEQc8=";
  };
  functionsDir =
    pkgs.runCommand "llm-functions-built"
      {
        nativeBuildInputs = [
          pkgs.argc
          pkgs.bash
          pkgs.jq
        ];
      }
      ''
        cp -r ${llm-functions}/. $out
        patchShebangs .
        chmod -R u+w $out
        cd $out

        cp ${./tools}/*.sh tools/
        chmod +x tools/*.sh
        cp ${./tools.txt} tools.txt

        ${lib.optionalString (builtins.pathExists ./agents.txt) ''
          cp ${./agents.txt} agents.txt
        ''}

        argc build@tool
        argc build-bin@tool
      '';
in
{
  options.modules.ai.enable = lib.mkEnableOption "ai";
  config = lib.mkIf cfg.enable {
    xdg.configFile."aichat/functions".source = functionsDir;
    programs.aichat = {
      enable = true;
      settings = {
        model = "llamacpp:qwen3.5-2";
        clients = [
          {
            type = "openai-compatible";
            name = "llamacpp";
            api_base = "https://genai.tail2f38ea.ts.net/v1";
            models = [
              {
                name = "qwen3.5-2";
                supports_function_calling = true;
              }
              {
                name = "qwen3.5";
                supports_function_calling = true;
              }
              {
                name = "qwen3.5-fast";
                supports_function_calling = true;
              }
              {
                name = "qwen3.5-0.8";
                supports_function_calling = true;
              }
            ];
          }
        ];
      };
    };
  };
}
