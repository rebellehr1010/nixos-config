{ pkgs, ... }:
{
  networking = {
    firewall.enable = false;
    networkmanager = {
      enable = true;
      plugins = with pkgs; [
        networkmanager-openvpn
      ];
    };
  };

}
