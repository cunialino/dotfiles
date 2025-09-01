{ pkgs }:

let
  nvimPkgs = with pkgs; [
    neovim
    lua-language-server
  ];

in
{
  name = "nvim";
  packages = nvimPkgs;
}
