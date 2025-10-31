{ pkgs, ... }:
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
      gf = "git fetch";
      git-whitespace-fix = "git_whitespace_fix.sh";
      gp = "git pull";
      gst = "git status";
      gsuir = "git submodule update --init --recursive";
      header-include-fix = "header_include_fix.sh";
      ls = "eza";
      lsta = "start_logging.sh";
      lsto = "tmux kill-session -t logging";
      nrs = "sudo nixos-rebuild switch --flake /etc/nixos"; # Use flake with auto host selection
      nfu = "nix flake update /etc/nixos";
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
      # calibre
      caprine
      cmake
      dconf-editor
      discord-ptb
      efibootmgr
      eza
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
      micro
      ncdu
      ninja
      nixfmt
      nodejs
      obsidian
      os-prober
      pciutils
      prusa-slicer
      qbittorrent
      ripgrep
      ruff
      ryubing
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
}
