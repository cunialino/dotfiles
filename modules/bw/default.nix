{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.modules.bw;
in
{
  options.modules.bw.enable = lib.mkEnableOption "bw";
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      bitwarden-cli
    ];
    programs.bash.shellAliases = {
      bwun = "export BW_SESSION=$(bw unlock --raw)";
    };

  };
}
