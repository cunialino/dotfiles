{
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/core")
    (modulesPath + "/term")
    (modulesPath + "/nvim")
    (modulesPath + "/gui")
  ];

  home.username = "elia";
  home.homeDirectory = "/home/elia";

  home.stateVersion = "25.05";
}
