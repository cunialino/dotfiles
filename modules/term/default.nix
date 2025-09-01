{ pkgs }:

let
  termPkgs = with pkgs; [
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

in
{
  name = "term";
  packages = termPkgs;
}
