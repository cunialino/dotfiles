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
    pi-coding-agent.enable = true;
    comfy-gen.enable = true;
  };
}
