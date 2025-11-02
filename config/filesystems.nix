{ ... }:
{
  fileSystems."/mnt/server_media" = {
    device = "192.168.1.71:/server_media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
    ];

  };
  fileSystems."/mnt/apps" = {
    device = "192.168.1.71:/apps";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
    ];
  };
}
