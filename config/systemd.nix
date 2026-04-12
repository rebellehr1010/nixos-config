{ pkgs, ... }:
{
  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd = {
    services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
    };
    user = {
      services = {
        nixos-git-watch = {
          description = "Check /etc/nixos for git changes";
          path = [
            pkgs.git
            pkgs.openssh
            pkgs.yad
            pkgs.coreutils
          ];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/shell/nixos-git-watch.sh";
          };
        };
      };
      timers = {
        nixos-git-watch = {
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnStartupSec = "10s";
            OnUnitActiveSec = "1m";
            Unit = "nixos-git-watch.service";
          };
        };
      };
    };
  };
}
