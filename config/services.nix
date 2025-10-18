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
    openvpn.servers = {
      piaVPN = {
        config = ''config /etc/nixos/config/pia-vpn/au_australia-so-aes-128-cbc-udp-dns.ovpn '';
        updateResolvConf = true;
        authUserPass = {
          username = "p8146994";
          password = "G17DrMiv3&CSe3YgrVV&@i^Rras*I0";
        };
      };
    };
    pia = {
      enable = true;
      authUserPass = {
        username = "p8146994";
        password = "G17DrMiv3&CSe3YgrVV&@i^Rras*I0";
      };
      # Alternatively, you can use the `authUserPassFile` attribute if you are using a Nix secrets manager. Here's an example using sops-nix.
      # The secret you provide to `authUserPassFile` should be a multiline string with a single username on the first line a single password on the second line.
      # authUserPassFile = config.sops.secrets.pia.path;
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    printing.enable = true; # Enable CUPS to print documents.
    pulseaudio.enable = false; # Enable sound with pipewire.
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
