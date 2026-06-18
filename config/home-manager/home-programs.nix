{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      android-studio
      arp-scan
      bat
      brave
      # calibre
      caprine
      cmake
      # davinci-resolve
      dconf-editor
      discord-ptb
      dnsmasq
      efibootmgr
      ethtool
      eza
      fd
      ffmpeg
      file
      fzf
      gedit
      git
      gimp
      gnome-tweaks
      gprename
      htop
      inkscape
      jq
      libreoffice
      localsend
      losslesscut-bin
      micro
      ncdu
      nfs-utils
      ninja
      nixfmt
      nodejs
      obsidian
      os-prober
      pciutils
      peazip
      prusa-slicer
      qbittorrent
      ripgrep
      ruff
      ryubing
      tailscale
      thunderbird
      tldr
      tmux
      ty
      unzip
      usbutils
      uv
      virt-viewer
      vscode
      wget
      which
      wireshark
      yad
      yq-go
      yt-dlp
      zip
      # zoom
      zoxide
      zplug
      zsh
    ];
  };

  programs = {
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        user = {
          email = "riley.lehr@connectsource.com.au";
          name = "rebellehr1010";
        };
      };
    };
    gnome-shell = {
      enable = true;
      extensions = [
        { package = pkgs.gnomeExtensions.dash-to-dock; }
      ];
    };
    home-manager.enable = true;
    # virt-manager.enable = true;
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
          { name = "MichaelAquilina/zsh-you-should-use"; }
          { name = "fdellwing/zsh-bat"; }
          { name = "joshskidmore/zsh-fzf-history-search"; }
        ];
        zplugHome = "/home/riley/.zplug";
      };
      initContent = ''
        source ${pkgs.zplug}/share/zplug/init.zsh

        # Map terminal Ctrl+Arrow escape sequences to word movement in zsh.
        bindkey -M emacs "^[[1;5D" backward-word
        bindkey -M emacs "^[[1;5C" forward-word
        bindkey -M emacs "^[[1;5H" beginning-of-line
        bindkey -M emacs "^[[1;5F" end-of-line
        bindkey -M emacs "^[[5D" backward-word
        bindkey -M emacs "^[[5C" forward-word
        bindkey -M emacs "^[[7;5~" beginning-of-line
        bindkey -M emacs "^[[8;5~" end-of-line
        bindkey -M viins "^[[1;5D" backward-word
        bindkey -M viins "^[[1;5C" forward-word
        bindkey -M viins "^[[1;5H" beginning-of-line
        bindkey -M viins "^[[1;5F" end-of-line
        bindkey -M viins "^[[5D" backward-word
        bindkey -M viins "^[[5C" forward-word
        bindkey -M viins "^[[7;5~" beginning-of-line
        bindkey -M viins "^[[8;5~" end-of-line

        # Install any missing plugins quietly on first run
        if ! zplug check --verbose; then
          printf '\n[zplug] Installing missing plugins...\n' >&2
          zplug install
        fi

        zplug load

        # Powerlevel10k instant prompt (optional, improves startup)
        if [[ -r "/etc/nixos/config/zsh/.p10k.zsh" ]]; then
          source "/etc/nixos/config/zsh/.p10k.zsh"
        fi
      '';
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
