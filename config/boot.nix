{ pkgs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "nfs" ];
  };

  # Size at boot for each machine: about 4 GiB on the 8 GB HP, up to 8 GiB
  # on larger machines. This is logical swap capacity, allocated on demand;
  # the compressed pages use RAM. Prefer it over disk-backed swap.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    memoryMax = 8 * 1024 * 1024 * 1024;
    priority = 100;
  };
}
