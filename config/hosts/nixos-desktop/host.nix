{ config, ... }:
{
  networking.hostName = "nixos-desktop"; # Desktop hostname

  # Retain scheduled maintenance without running missed jobs during login.
  # This desktop is normally on overnight; laptops keep their catch-up policy.
  nix.optimise.persistent = false;
  system.autoUpgrade.persistent = false;
  systemd = {
    timers.fstrim.timerConfig.Persistent = false;
    # Optimisation has used 17 GiB of cache here; reclaim it before it crowds
    # out desktop applications, and give interactive work priority.
    services.nix-optimise.serviceConfig = {
      MemoryHigh = "2G";
      CPUWeight = 10;
      IOWeight = 10;
    };
    services.nixos-upgrade.serviceConfig = {
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUWeight = 10;
      IOWeight = 10;
    };
  };

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
