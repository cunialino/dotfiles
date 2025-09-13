{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    curl
    wget
    gcc
    uv
  ];

  programs.git = {
    enable = true;
    userName = "Elia Cunial";
    userEmail = "elia.cunial@gmail.com";

    difftastic = {
      enable = true;
      enableAsDifftool = true;
      background = "dark";
      color = "auto";
      display = "side-by-side";
    };

    extraConfig = {
      credential.helper = "cache";

      filter.lfs = {
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
      };

      init.defaultBranch = "main";
    };

    includes = [
      {
        path = "~/WORK/.gitconfig";
        condition = "gitdir:~/WORK/";
      }
    ];

  };
}
