{ ... }:
{
  fileSystems."/mnt/server/server_media" = {
    device = "192.168.1.71:/mnt/HDDs/server_media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=3"
    ];

  };
  fileSystems."/mnt/server/apps" = {
    device = "192.168.1.71:/mnt/app_pool/apps";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=3"
    ];
  };
}
