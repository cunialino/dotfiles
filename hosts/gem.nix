{
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/common")
    (modulesPath + "/core")
    (modulesPath + "/term")
    (modulesPath + "/nvim")
  ];

  home.username = "elia";
  home.homeDirectory = "/home/elia";

  home.stateVersion = "25.05";
}
