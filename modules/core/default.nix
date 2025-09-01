{ pkgs }:

let
  corePkgs = with pkgs; [
    git
    curl
    wget
    gcc
    uv
  ];
in
{
  name = "core";
  packages = corePkgs;
}
