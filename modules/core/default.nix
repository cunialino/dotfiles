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
}
