{ ... }:
let
  # Bound initial connection attempts and release unused NAS mounts. Keep hard
  # NFS retries to protect writes during an outage. The mount timeout does not
  # limit I/O waits on an already-mounted share.
  nasOptions = [
    "x-systemd.automount"
    "noauto"
    "nofail"
    "x-systemd.mount-timeout=5s"
    "x-systemd.idle-timeout=1min"
    "x-gvfs-hide"
    "nfsvers=3"
    "hard"
  ];
in
{
  fileSystems."/mnt/server/server_media" = {
    device = "192.168.1.71:/mnt/HDDs/server_media";
    fsType = "nfs";
    options = nasOptions;
  };
  fileSystems."/mnt/server/apps" = {
    device = "192.168.1.71:/mnt/app_pool/apps";
    fsType = "nfs";
    options = nasOptions;
  };
}
