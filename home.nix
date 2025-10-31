{
  config,
  pkgs,
  lib,
  ...
}:
{

  # Home Manager Option Search - https://home-manager-options.extranix.com/
  # Home Manager Configuration Options - https://nix-community.github.io/home-manager/options.xhtml
  # Nixos Search - https://search.nixos.org/

  imports = [
    ./config/home-manager/dconf.nix
    ./config/home-manager/home-config.nix
    ./config/home-manager/home-programs.nix
  ];

  home.stateVersion = "25.05";
}
