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
      core.enable = true;
      term.enable = true;
    };
  };
}
