{
  modulesPath,
  pkgs,
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
      opencode.enable = true;
    };
    home.packages = with pkgs; [
      awscli2
    ];
    home.sessionVariables = {
      TMPDIR="/home/d00f192.linux/tmp";
    };
    home.username = "d00f192";
    home.homeDirectory = "/home/d00f192.linux";
    home.stateVersion = "26.05";
  };
}
