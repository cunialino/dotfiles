{
  modulesPath,
  ...
}:

{
  imports = [
    modulesPath
  ];

  config = {
    modules = {
      nvim.enable = true;
      core.enable = true;
      term.enable = true;
      gui.enable = false;
      tmux.enable = true;
    };
    home.username = "elia";
    home.homeDirectory = "/home/elia";
    home.stateVersion = "25.05";
  };
}
