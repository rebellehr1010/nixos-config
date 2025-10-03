{ config, pkgs, ... }:

{
  # TODO please change the username & home directory to your own
  home.username = "riley";
  home.homeDirectory = "/home/riley";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi for 4k monitor
  # xresources.properties = {
  #   "Xcursor.size" = 16;
  #   "Xft.dpi" = 172;
  # };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # here is some command line tools I use frequently
    # feel free to add your own or remove some of them

    # archives
    zip
    unzip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processor https://github.com/mikefarah/yq
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # misc
    file
    which

    pciutils # lspci
    usbutils # lsusb
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

  ];

  # basic configuration of git, please change to your own
  programs = {
    git = {
      enable = true;
      userName = "rebellehr1010";
      userEmail = "riley.lehr@connectsource.com.au";
      config = {
        init = {
          defaultBranch = "main";
        };
        user.name = "rebellehr1010";
        user.email = "riley.lehr@connectsource.com.au";
      };
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    zoxide = {
      enable = true;
      enableZshIntegration = true;
      flags = [ "--cmd cd" ];
    };
    zsh = {
      enable = true;
      ohMyZsh = {
        enable = true;
        theme = "frisk";
        plugins = [
          "copybuffer"
          "copyfile"
          "command-time"
          "dirhistory"
          "fzf-tab"
          "fzf-zsh-plugin"
          "git"
          "history"
          "sudo"
          "you-should-use"
          "zsh-autosuggestions"
          "zsh-bat"
          "zsh-syntax-highlighting"
        ];
      };
      syntaxHighlighting = {
        enable = true;
      };
      enableCompletion = true;
      autosuggestions.enable = true;
    };
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
