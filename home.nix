{
  config,
  pkgs,
  lib,
  ...
}:
{
  home = {
    username = "riley";
    homeDirectory = "/home/riley";
    sessionPath = [ "/etc/nixos/shell" ];
    shellAliases = {
      clear-ob = "clear_ob.sh";
      commands = "commands.sh";
      config-gcc = "config_gcc.sh";
      dff = "dart format . && dart fix --apply && dart format .";
      fcg = "flutter clean && flutter pub get";
      files = "files.sh";
      fix-includes = "fix_includes.sh";
      fpg = "flutter pub get";
      ft = "flutter test";
      ftff = "flutter test --fail-fast";
      g = "git";
      git-whitespace-fix = "git_whitespace_fix.sh";
      gsuir = "git submodule update --init --recursive";
      header-include-fix = "header_include_fix.sh";
      ls = "eza";
      lsta = "start_logging.sh";
      lsto = "tmux kill-session -t logging";
      nrs = "sudo nixos-rebuild switch --flake /etc/nixos"; # Use flake with auto host selection
      prettier = "prettier.sh";
      remove-gcc = "remove_gcc.sh";
      rs = "source ~/.zshrc";
      start-logging = "start_logging.sh";
      ta = "tmux a -t";
      tk = "tmux kill-session -t";
      tl = "tmux ls";
      tmux = "tmux -2";
      tn = "tmux new -A -s";
      update = "update.sh";
    };
    packages = with pkgs; [
      android-studio
      bat
      brave
      caprine
      cmake
      dconf-editor
      efibootmgr
      eza
      file
      fzf
      gedit
      git
      gnome-tweaks
      gprename
      htop
      jq
      micro
      ncdu
      ninja
      nixfmt
      nodejs
      obsidian
      os-prober
      pciutils
      qbittorrent
      ripgrep
      ruff
      stm32cubemx
      tailscale
      tldr
      tmux
      ty
      unzip
      usbutils
      uv
      vscode
      wget
      whatsapp-electron
      which
      yq-go
      zip
      zoxide
      zplug
      zsh
    ];
  };

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
      "org/gnome/desktop/wm/keybindings" = {
        switch-to-workspace-up = [ ];
        switch-to-workspace-down = [ ];
        switch-to-workspace-left = [ ];
        switch-to-workspace-right = [ ];
      };
    };
  };

  programs = {
    git = {
      enable = true;
      userName = "rebellehr1010";
      userEmail = "riley.lehr@connectsource.com.au";
      extraConfig.init.defaultBranch = "main";
    };
    home-manager.enable = true;
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
