{ pkgs, ... }:
{
  home.packages = with pkgs; [
    google-chrome
  ];

  home.file.".local/share/applications/gc.desktop".source = ./google-chrome.desktop;
}
