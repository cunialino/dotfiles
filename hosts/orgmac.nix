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
      # No MCP servers on orgmac, deliberately: this is a work box and it should
      # have no route into the home cluster -- neither the kube-vip LAN addresses
      # nor the ts.net ingresses. pi runs here, it just runs without servers.
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
