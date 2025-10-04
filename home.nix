{
  config,
  pkgs,
  lib,
  ...
}:
let
  zshPlugins = import ./config/zsh_plugins.nix { inherit pkgs lib; };
in
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

  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";

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
      initContent = ''
        export ZPLUG_HOME="$HOME/.zplug"
        source ${pkgs.zplug}/share/zplug/init.zsh

        # Plugins (themes/plugins) managed by zplug
        zplug "zsh-users/zsh-autosuggestions"
        zplug "zsh-users/zsh-completions"
        zplug "zsh-users/zsh-syntax-highlighting"
        zplug "zsh-users/zsh-history-substring-search"
        zplug "romkatv/powerlevel10k", as:theme, depth:1
        zplug "spwhitt/nix-zsh-completions"
        zplug "popstas/zsh-command-time"
        zplug "Aloxaf/fzf-tab"
        zplug "unixorn/fzf-zsh-plugin"
        zplug "MichaelAquilina/zsh-you-should-use"
        zplug "fdellwing/zsh-bat"
        zplug "joshskidmore/zsh-fzf-history-search"

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
