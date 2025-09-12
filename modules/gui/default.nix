{
  pkgs,
  lib,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      google-chrome
      noto-fonts-color-emoji
    ]
    ++ (with pkgs.nerd-fonts; [ sauce-code-pro ]);

  home.file.".local/share/applications/gc.desktop".source = ./google-chrome.desktop;

  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      monospace = [ "Sauce Code Pro Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  home.activation = {
    refresh-font-cache = lib.hm.dag.entryAfter [ "installPackages" ] ''
      ${pkgs.fontconfig}/bin/fc-cache -f -v
    '';
  };
}
