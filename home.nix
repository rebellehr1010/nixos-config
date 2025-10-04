{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.username = "riley";
  home.homeDirectory = "/home/riley";

  home.packages = with pkgs; [
    zip
    unzip
    ripgrep
    jq
    yq-go
    eza
    fzf
    file
    which
    pciutils
    usbutils
    git
    wget
    gedit
    micro
    brave
    vscode
    htop
    nixfmt
    os-prober
    efibootmgr
    obsidian
    tldr
    caprine
    whatsapp-electron
    zsh
    zoxide
    zplug
  ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          "dash-to-dock@micxgx.gmail.com"
        ];

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
      "org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";
    };
  };

  programs = {
    git = {
      enable = true;
      userName = "rebellehr1010";
      userEmail = "riley.lehr@connectsource.com.au";
      extraConfig.init.defaultBranch = "main";
    };
    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true; # Still provide autosuggestion via HM; zplug will also fetch its version.

      # We'll rely on zplug for syntax highlighting, so disable HM's built-in to avoid duplication.
      syntaxHighlighting.enable = false;
      # Using initContent (initExtra deprecated) with zplug-managed plugins.
      zplug = {
        enable = true;
        plugins = [
          { name = "zsh-users/zsh-autosuggestions"; }
          { name = "zsh-users/zsh-completions"; }
          { name = "zsh-users/zsh-syntax-highlighting"; }
          { name = "zsh-users/zsh-history-substring-search"; }
          {
            name = "romkatv/powerlevel10k";
            tags = [
              "as:theme"
              "depth:1"
            ];
          }
          { name = "spwhitt/nix-zsh-completions"; }
          { name = "popstas/zsh-command-time"; }
          { name = "Aloxaf/fzf-tab"; }
          { name = "unixorn/fzf-zsh-plugin"; }
          { name = "MichaelAquilina/zsh-you-should-use"; }
          { name = "fdellwing/zsh-bat"; }
          { name = "joshskidmore/zsh-fzf-history-search"; }
        ];
        zplugHome = "/home/riley/.zplug";
      };
      initContent = ''
        source ${pkgs.zplug}/share/zplug/init.zsh

        # Install any missing plugins quietly on first run
        if ! zplug check --verbose; then
          printf '\n[zplug] Installing missing plugins...\n' >&2
          zplug install
        fi

        zplug load

        # Powerlevel10k instant prompt (optional, improves startup)
        if [[ -r "$HOME/.p10k.zsh" ]]; then
          source "$HOME/.p10k.zsh"
        fi
      '';
    };
  };

  home.stateVersion = "25.05";
}
