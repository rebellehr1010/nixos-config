# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  # imports = [# Include the results of the hardware scan.];
  nix = {
    optimise.automatic = true;
    settings = {
      auto-optimise-store = true; # Potentially slows down builds.
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  # Temporary workarounds for Calibre's speech dependencies.
  nixpkgs.overlays = [
    (final: prev: {
      # Calibre uses Python 3.14; speechd needs the interpreter at configure time
      # under strictDeps, otherwise it silently omits its Python bindings.
      calibre = prev.calibre.override {
        speechd-minimal = prev.speechd-minimal.overrideAttrs (oldAttrs: {
          nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ final.python314 ];
          configureFlags = oldAttrs.configureFlags ++ [ "--enable-python" ];
        });
      };
      # Accept both Cython error wordings while retaining the regression checks.
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pythonFinal: pythonPrev: {
          pyopenjtalk-plus = pythonPrev.pyopenjtalk-plus.overridePythonAttrs (oldAttrs: {
            postPatch = (oldAttrs.postPatch or "") + ''
              substituteInPlace tests/test_frontend.py \
                --replace-fail 'match="must be str"' 'match="must be str|Expected str, got int"'
            '';
          });
        })
      ];
    })
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system = {
    stateVersion = "25.05"; # Did you read the comment?
    autoUpgrade = {
      enable = true;
      flake = "/etc/nixos#${config.networking.hostName}";
      # Flake inputs are refreshed explicitly below, rather than via channels.
      upgrade = false;
    };
  };

  # Keep Nixpkgs and Home Manager in step, and leave lockfile changes available
  # for review/commit. Run as the repository owner so the lock stays editable.
  systemd.services.nixos-upgrade.preStart = ''
    ${pkgs.util-linux}/bin/runuser -u riley -- \
      ${config.nix.package}/bin/nix flake update nixpkgs home-manager --flake /etc/nixos
  '';
}
