{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    bottom
    difftastic
    du-dust
    fd
    just
    nushell
    ripgrep
    sd
    starship
    television
    vulnix
    yazi
    zellij
  ];

  programs.bat.enable = true;

  programs.lazygit = {
    enable = true;
    settings.git.paging = {
      colorArg = "always";
      externalDiffCommand = "difft --color=always";
    };
  };
  programs.bottom = {
    enable = true;

    settings = {
      flags = {
        enable_gpu_memory = true;
      };

      row = [
        {
          ratio = 30;
          child = [
            { type = "cpu"; }
          ];
        }
        {
          ratio = 30;
          child = [
            { type = "mem"; }
          ];
        }
        {
          ratio = 30;
          child = [
            { type = "proc"; }
          ];
        }
      ];
    };
  };

}
