{ pkgs, ... }:
{
  networking = {
    # Hostname is now set in per-host modules under config/hosts/*/host.nix
    networkmanager = {
      enable = true;
      plugins = with pkgs; [ networkmanager-openvpn ];
    };
  };
}
