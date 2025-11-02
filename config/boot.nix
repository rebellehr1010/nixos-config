{ config, pkgs, ... }: # <-- Add 'config' here
{
  boot = {
    blacklistedKernelModules = [ "r8169" ];
    extraModulePackages = [ config.boot.kernelPackages.r8125 ];
    kernelModules = [ "r8125" ];
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
}
