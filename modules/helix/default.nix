{ pkgs }:

let
  helixPkgs = with pkgs; [
    helix
    nil
    nixfmt
    kdlfmt
  ];
in
{
  name = "hx";
  packages = helixPkgs;
}
