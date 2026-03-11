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
      ai.enable = true;
    };
    home.username = "D00F192";
    home.homeDirectory = "/Users/d00f192";
    home.stateVersion = "25.05";
  };
}
