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

  # Terminal multiplexer for running coding agents side by side (https://herdr.dev).
  programs.herdr.enable = true;
}
