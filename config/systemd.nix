{ pkgs, ... }:
{
  systemd = {
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
            OnStartupSec = "1m";
            OnUnitActiveSec = "10m";
            Unit = "nixos-git-watch.service";
          };
        };
      };
    };
  };
}
