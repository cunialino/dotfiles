{
  modulesPath,
  catppuccin,
  ...
}:

{
  imports = [
    modulesPath
    catppuccin.homeModules.catppuccin
  ];

  config = {
    modules = {
      nvim.enable = true;
      core.enable = true;
      term.enable = true;
      gui.enable = true;
      tmux.enable = true;
      bw.enable = true;
      ai.enable = true;
      opencode.enable = true;
      ghostty.enable = true;
    };

  };
}
