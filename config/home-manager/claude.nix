{ config, pkgs, ... }:
let
  # herdr's Claude integration normally writes a hook script and merges a
  # SessionStart hook into ~/.claude/settings.json. That file is a read-only
  # Nix store symlink here, so `herdr integration install claude` fails with
  # "Permission denied". Instead, generate the hook script from the herdr
  # package at build time and declare the hook in settings below.
  herdrClaudeHook =
    pkgs.runCommand "herdr-claude-hook" { nativeBuildInputs = [ config.programs.herdr.package ]; }
      ''
        export HOME=$TMPDIR
        mkdir -p $HOME/.claude
        echo '{}' > $HOME/.claude/settings.json
        CLAUDE_CONFIG_DIR=$HOME/.claude herdr integration install claude
        install -Dm755 $HOME/.claude/hooks/herdr-agent-state.sh $out
      '';

  # Status line: directory, model, and 5-hour / 7-day subscription usage.
  claudeStatusline = pkgs.writeShellScript "claude-statusline" ''
    export PATH=${pkgs.lib.makeBinPath [ pkgs.jq pkgs.coreutils ]}:$PATH
    ${builtins.readFile ./claude-statusline.sh}
  '';
in
{
  # Shared MCP server definitions (usable by any home-manager module with MCP integration).
  programs.mcp = {
    enable = true;
    servers = {
      nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
  };

  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;

    # Merge the declared settings into a writable ~/.claude/settings.json at
    # activation instead of symlinking a read-only store file, so Claude Code
    # can persist runtime choices (/model, /config, ...). Declared keys win on
    # every switch; keys Claude adds itself are preserved.
    mutableSettings = true;

    settings = {
      theme = "dark";

      statusLine = {
        type = "command";
        command = "${claudeStatusline}";
      };

      # herdr agent-state integration (equivalent of `herdr integration install claude`).
      hooks.SessionStart = [
        {
          matcher = "^(startup|resume|clear|compact|fork)$";
          hooks = [
            {
              type = "command";
              command = "bash ${herdrClaudeHook} session";
              timeout = 10;
            }
          ];
        }
      ];
    };
  };

  # Prompt keys: Enter / Shift+Enter insert a newline, Ctrl+Enter submits.
  # Alt+Enter also submits as a fallback for terminals that cannot tell
  # Ctrl+Enter apart from Enter (e.g. GNOME Console/VTE, which lacks the kitty
  # keyboard protocol) - without it, a prompt could never be sent there.
  # Claude Code only reads this file, so a read-only store symlink is fine.
  home.file.".claude/keybindings.json".text = builtins.toJSON {
    "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
    "$docs" = "https://code.claude.com/docs/en/keybindings";
    bindings = [
      {
        context = "Chat";
        bindings = {
          "enter" = "chat:newline";
          "shift+enter" = "chat:newline";
          "ctrl+enter" = "chat:submit";
          "alt+enter" = "chat:submit";
        };
      }
    ];
  };

  # Terminal multiplexer for running coding agents side by side (https://herdr.dev).
  # herdr negotiates the kitty keyboard protocol with the host terminal and
  # re-encodes keys per pane, so Ctrl/Shift+Enter reach Claude intact as long
  # as the outer terminal supports that protocol (Ghostty does; see below).
  programs.herdr.enable = true;

  # Ghostty: host terminal with kitty keyboard protocol support, needed for
  # Ctrl+Enter / Shift+Enter to be distinguishable from Enter.
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      # Ghostty binds Ctrl+Enter to toggle_fullscreen on Linux by default;
      # release it so it reaches herdr/Claude.
      keybind = [ "ctrl+enter=unbind" ];
    };
  };
}
