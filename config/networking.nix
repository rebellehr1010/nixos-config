{ pkgs, ... }:
{
  networking = {
    firewall.enable = false;
    hosts = {
      "192.168.1.71" = [ "riley-server" ];
    };
    networkmanager = {
      enable = true;
      plugins = with pkgs; [
        networkmanager-openvpn
      ];
    };
  };

}
