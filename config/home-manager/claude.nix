{ pkgs, ... }:
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
    };
  };

  # Terminal multiplexer for running coding agents side by side (https://herdr.dev).
  programs.herdr.enable = true;
}
