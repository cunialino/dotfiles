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
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        instructions = [ ./instructions/system.md ];
      };
    };
  };
}
