{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    bottom
    difftastic
    du-dust
    fd
    just
    nushell
    ripgrep
    sd
    starship
    television
    vulnix
    yazi
    zellij
  ];

  programs.bat.enable = true;
}
