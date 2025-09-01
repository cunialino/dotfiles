{
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/core")
    (modulesPath + "/term")
  ];

  home.username = "elia";
  home.homeDirectory = "/home/elia";

  home.stateVersion = "25.05";
}
