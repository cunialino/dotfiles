{ pkgs }:

let
  dir = ./.;

  allNames = builtins.attrNames (builtins.readDir dir);

  names = builtins.filter (n: n != "default.nix") allNames;

  modules = builtins.listToAttrs (
    map (name: {
      name = name;
      value = import (builtins.toString dir + "/" + name) { inherit pkgs; };
    }) names
  );
in
modules
