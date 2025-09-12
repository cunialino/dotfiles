{ ... }: {
  home.enableNixpkgsReleaseCheck = false;
  catppuccin.enable = true;
  catppuccin.flavor = "mocha";
  catppuccin.accent = "blue";
  programs.home-manager.enable = true;

}

