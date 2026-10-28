{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    # in configuration.nix
    sessionVariables.GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" [
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-bad
      pkgs.gst_all_1.gst-plugins-ugly
      pkgs.gst_all_1.gst-libav
    ];
    systemPackages = with pkgs; [
      inputs.nix-software-center.packages."${pkgs.stdenv.hostPlatform.system}".nix-software-center
      bind.dnsutils # nslookup, dig, and host
      dnsmasq
      gnome-boxes
      openssl
      phodav
      nix-fast-build
      (pkgs.writeShellApplication {
        name = "nfb";
        runtimeInputs = [
          pkgs.nix-fast-build
          pkgs.coreutils
        ];
        text = ''
          # Build this host only, using the repository's locked inputs. Keep
          # the result rooted until a later switch (or the next build).
          result_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/nixos-fast-build/${config.networking.hostName}"
          mkdir -p "$result_dir"
          exec nix-fast-build \
            --flake '/etc/nixos#nixosConfigurations.${config.networking.hostName}.config.system.build.toplevel' \
            --eval-workers 1 \
            --out-link "$result_dir/result" \
            "$@"
        '';
      })
    ];
    variables.EDITOR = "micro";
  };

  programs = {
    anycubicSlicer.enable = true;
    nix-ld.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    zsh.enable = true;
  };
}
