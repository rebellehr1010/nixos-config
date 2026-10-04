{ config, ... }:
{
  networking.hostName = "nixos-desktop"; # Desktop hostname

  # This desktop's RTL8125 controller needs the vendor driver override.
  boot = {
    blacklistedKernelModules = [ "r8169" ];
    extraModulePackages = [ config.boot.kernelPackages.r8125 ];
    kernelModules = [ "r8125" ];
  };
}
