{ config, ... }:
{
  networking.hostName = "nixos-desktop"; # Desktop hostname

  # This desktop's RTL8125 controller needs the vendor driver override.
  boot = {
    blacklistedKernelModules = [ "r8169" ];
    extraModulePackages = [
      (config.boot.kernelPackages.r8125.overrideAttrs (oldAttrs: {
        # Use upstream's Kbuild install target so the module gets its .ko.cer.
        # Workaround for https://github.com/NixOS/nixpkgs/issues/575192.
        installPhase = null;
        makeFlags = oldAttrs.makeFlags ++ [
          "INSTALL_MOD_PATH=${placeholder "out"}"
          "DEPMOD=true"
        ];
      }))
    ];
    kernelModules = [ "r8125" ];
  };
}
