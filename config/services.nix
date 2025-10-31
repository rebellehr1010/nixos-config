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
