{ lib, pkgs, ... }:
let
  freecad = pkgs.freecad;

  # https://github.com/neka-nat/freecad-mcp — two halves from one repo:
  #  * addon/FreeCADMCP: a FreeCAD workbench that runs an XML-RPC server (localhost:9875)
  #  * src/freecad_mcp: the stdio MCP server Claude Code launches, which talks to that RPC server
  freecadMcpVersion = "0.1.31";
  freecadMcpSrc = pkgs.fetchFromGitHub {
    owner = "neka-nat";
    repo = "freecad-mcp";
    rev = "v${freecadMcpVersion}";
    hash = "sha256-bUi0HxCZ/nx3RwUE17k6gQ7n/sUPZRdpb4d59UCb9V8=";
  };

  freecad-mcp = pkgs.python3Packages.buildPythonApplication {
    pname = "freecad-mcp";
    version = freecadMcpVersion;
    pyproject = true;
    src = freecadMcpSrc;

    build-system = [ pkgs.python3Packages.hatchling ];
    dependencies = with pkgs.python3Packages; [
      anyio
      certifi
      mcp
      pyjwt
      validators
    ];
    pythonImportsCheck = [ "freecad_mcp.server" ];
  };

  # FreeCAD 1.1+ uses versioned user dirs (~/.local/share/FreeCAD/v1-1/).
  freecadUserDir =
    let
      v = lib.versions;
    in
    "FreeCAD/v${v.major freecad.version}-${v.minor freecad.version}";
in
{
  home.packages = [
    freecad
    # Nightly build: Manifold backend renders orders of magnitude faster than the 2021.01 release.
    pkgs.openscad-unstable
  ];

  # Install the addon read-only from the Nix store.
  xdg.dataFile."${freecadUserDir}/Mod/FreeCADMCP".source = "${freecadMcpSrc}/addon/FreeCADMCP";

  # Seed the addon's settings so the RPC server auto-starts with FreeCAD. The addon rewrites
  # this file from its menu (auto-start, remote access, auth token), so it must stay a
  # writable file rather than a store symlink — only create it when absent.
  home.activation.freecadMcpSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${"$"}{XDG_DATA_HOME:-$HOME/.local/share}/${freecadUserDir}/freecad_mcp_settings.json"
    if [ ! -e "$settings" ]; then
      run mkdir -p "$(dirname "$settings")"
      run ${lib.getExe' pkgs.coreutils "install"} -m 600 /dev/stdin "$settings" <<'EOF'
    {"remote_enabled": false, "allowed_ips": "127.0.0.1", "auto_start_rpc": true, "auth_token": ""}
    EOF
    fi
  '';

  programs.mcp.servers.freecad = {
    command = lib.getExe' freecad-mcp "freecad-mcp";
    # Used by the execute_code_headless tool; pinned so it matches the GUI's FreeCAD.
    args = [
      "--freecadcmd"
      (lib.getExe' freecad "freecadcmd")
    ];
  };
}
