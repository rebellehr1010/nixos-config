{ ... }:
{
  networking = {
    # Hostname is now set in per-host modules under config/hosts/*/host.nix
    networkmanager.enable = true;
  };
}
