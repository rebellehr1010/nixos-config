{ pkgs, ... }:
{
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
        if [[ -r "/etc/nixos/config/zsh/.p10k.zsh" ]]; then
          source "/etc/nixos/config/zsh/.p10k.zsh"
        fi
      '';
    };
  };
}
