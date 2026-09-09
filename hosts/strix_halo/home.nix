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

  config.modules = {
    core.enable = true;
    nvim.enable = true;
    term.enable = true;
    tmux.enable = true;
  };
}
