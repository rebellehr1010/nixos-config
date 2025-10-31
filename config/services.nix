{ ... }:
{
  services = {
    desktopManager.gnome.enable = true; # Enable the GNOME Desktop Environment.
    displayManager = {
      gdm.enable = true;
      autoLogin.enable = false;
      # autoLogin.user = "riley";
    };
    fwupd.enable = true; # Enable firmware updates.
    # pia = {
    #   enable = true;
    #   authUserPass = {
    #     username = "p8146994";
    #     password = "G17DrMiv3&CSe3YgrVV&@i^Rras*I0";
    #   };
    # };
    openvpn = {
      servers = {
        au-perth = {
          config = ''config /etc/nixos/config/openvpn/au_perth.conf'';
          updateResolvConf = true;
        };
        au-melbourne = {
          config = ''config /etc/nixos/config/openvpn/au_melbourne.conf'';
          updateResolvConf = true;
        };
        au-sydney = {
          config = ''config /etc/nixos/config/openvpn/au_sydney.conf'';
          updateResolvConf = true;
        };
      };
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    printing.enable = true; # Enable CUPS to print documents.
    pulseaudio.enable = false; # Enable sound with pipewire.
    qbittorrent.enable = true; # Enable qBittorrent client service.
    tailscale.enable = true; # Enable Tailscale VPN.
    xserver = {
      enable = true; # Enable the X11 windowing system.
      xkb = {
        # Configure keymap in X11
        layout = "au";
        variant = "";
      };
    };
  };
}
