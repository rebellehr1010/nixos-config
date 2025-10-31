{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./config/home-manager/dconf.nix
    ./config/home-manager/home-config.nix
    ./config/home-manager/home-programs.nix
  ];

  home.stateVersion = "25.05";
}
