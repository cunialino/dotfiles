{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    bat
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
}
