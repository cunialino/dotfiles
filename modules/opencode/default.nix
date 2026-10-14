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
  options.modules.opencode = {
    enable = lib.mkEnableOption "opencode";
    macNotifications = {
      enable = lib.mkEnableOption "OpenCode notifications on the macOS host over SSH";
      destination = lib.mkOption {
        type = lib.types.str;
        description = "SSH user@host for the macOS notification recipient.";
        example = "user@host.lima.internal";
      };
      identityFile = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the SSH private key in the guest.";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        instructions = [ ./instructions/system.md ];
      };
    };
    xdg.configFile."opencode/plugins/mac-notifications.js" = lib.mkIf cfg.macNotifications.enable {
      text = builtins.replaceStrings
        [ "@ssh@" "@destination@" "@identityFile@" ]
        [
          (builtins.toJSON "${pkgs.openssh}/bin/ssh")
          (builtins.toJSON cfg.macNotifications.destination)
          (builtins.toJSON cfg.macNotifications.identityFile)
        ]
        (builtins.readFile ./mac-notifications.js);
    };
  };
}
