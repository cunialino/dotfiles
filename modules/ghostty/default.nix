{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.ghostty;
in
{
  options.modules.ghostty.enable = lib.mkEnableOption "ghostty";
  config = lib.mkIf cfg.enable {
    programs.ghostty.enable = true;
  };
}
