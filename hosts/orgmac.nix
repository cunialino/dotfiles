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
      pi-coding-agent.enable = true;
      mcp.enable = true;
      mcp.servers = {
        graphiti.url = "https://graphiti.tail2f38ea.ts.net/mcp";
        k8s-ddg-search.url = "https://ddg.tail2f38ea.ts.net/mcp";
      };
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
