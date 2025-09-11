{ ... }: {
  home.enableNixpkgsReleaseCheck = false;
  catppuccin.enable = true;
  catppuccin.flavor = "mocha";
  programs.home-manager.enable = true;

}

