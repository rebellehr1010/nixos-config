{ ... }:
{
  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
    };
    desktopManager.gnome.enable = true; # Enable the GNOME Desktop Environment.
    displayManager = {
      gdm.enable = true;
      autoLogin.enable = false;
    };
    fwupd.enable = true; # Enable firmware updates.
    openvpn = {
      servers = {
        # au-perth = {
        #   config = ''config /etc/nixos/config/openvpn/au_perth.conf'';
        #   updateResolvConf = true;
        # };
        # au-melbourne = {
        #   config = ''config /etc/nixos/config/openvpn/au_melbourne.conf'';
        #   updateResolvConf = true;
        # };
        # au-sydney = {
        #   config = ''config /etc/nixos/config/openvpn/au_sydney.conf'';
        #   updateResolvConf = true;
        # };
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
    resolved = {
      enable = true;
      settings.Resolve = {
        LLMNR = true;
        MulticastDNS = true;
      };
    };
    rpcbind.enable = true; # Enable rpcbind for NFS support.
    # Keep enough resolution to investigate short freezes after they end.
    sysstat = {
      enable = true;
      collect-frequency = "*:*:0/10";
    };
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

  systemd.timers.sysstat-collect.timerConfig.AccuracySec = "1s";
  environment.etc."sysconfig/sysstat".text = ''
    HISTORY=7
    SADC_OPTIONS="-S DISK"
  '';
}
