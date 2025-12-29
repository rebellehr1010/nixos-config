{ pkgs, ... }:
{
  # Use `dconf-editor` to find these settings
  # Use `dconf watch /` to see changes live
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/wm/keybindings" = {
        switch-to-workspace-up = [ ];
        switch-to-workspace-down = [ ];
        switch-to-workspace-left = [ ];
        switch-to-workspace-right = [ ];
      };
      "org/gnome/desktop/wm/preferences" = {
        button-layout = ":minimize,maximize,close";
      };
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Control><Alt>t";
        command = "kgx";
        name = "Console";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        binding = "<Super>e";
        command = "nautilus";
        name = "Files";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
        binding = "<Super><Shift>s";
        command = "gnome-screenshot -i";
        name = "Screenshot";
      };
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          "dash-to-dock@micxgx.gmail.com"
        ];
        favorite-apps = [ ];
      };
      "org/gnome/shell/extensions/dash-to-dock" = {
        multi-monitor = true;
        dock-position = "BOTTOM";
        dock-fixed = true;
        extend-height = true;
        always-center-icons = true;
        dash-max-icon-size = 40;
        preview-size-scale = 0.0;
        show-favorites = true;
        show-running = true;
        show-windows-preview = true;
        workspace-agnostic-urgent-windows = true;
        scroll-to-focused-applications = true;
        show-show-apps-button = true;
        click-action = "minimize-or-preview";
        custom-theme-shrink = true;
        disable-overview-on-startup = false;
        apply-custom-theme = true;
      };
    };
  };
}
