# riley-server HDDs startup and enclosure recovery

Installed on 28 October 2026 against TrueNAS 25.10.7. The executable source is
[hdd-startup.py](hdd-startup.py); its safety tests are
[test_hdd_startup.py](test_hdd_startup.py). These files contain no credentials.
The persistent tasks and healthy-pool checks were verified after updating to
TrueNAS 25.10.8 on 12 November 2026.

## Diagnosis

The four WD3001FYYG SAS drives behind the LSISAS2116 controller and PMCSIERA
SXP 24x3G enclosure initially reported:

```text
Read Capacity(16) failed
Logical unit not ready, notify (enable spinup) required
```

On the observed boot, TrueNAS attempted to import HDDs at 17:27:53 and failed
at 17:27:55. The four SAS disks changed from zero to 5,860,533,168 sectors at
17:28:12, after the original spin-up script ran. Both disks in each of two
mirror vdevs are SAS drives, so losing those members prevents pool import.

The installed `/lib/systemd/system/ix-preinit.service` explicitly runs **after**
`ix-zfs.service`. Thus a PREINIT spin-up script cannot prepare disks before
TrueNAS's initial import attempt. The old script also called
`zfs.pool.import_all`, which returned `Method does not exist`, and discarded
that error. Its background start requests and fixed sleeps never checked
readiness or successful import.

The pool remained registered in TrueNAS (ID 18, GUID 9538639308343860317).
TrueNAS's import discovery deliberately excludes already-registered pools.
This explains why disconnecting and importing appeared necessary even after
the disks were working. Re-running the native boot import recovered the
existing pool without disconnecting it or changing its registration.

Sources: the server's kernel journal, `/var/log/middlewared.log`, installed
middleware source `plugins/pool_/import_pool.py`, and installed systemd units.
The [upstream PREINIT unit](https://github.com/truenas/middleware/blob/master/debian/debian/ix-preinit.service)
also records the ordering. TrueNAS documents the supported task facility in
[Managing Init/Shutdown Scripts](https://www.truenas.com/docs/scale/25.04/scaletutorials/systemsettings/advanced/manageinitshutdownscale/).

The first enclosure cold-start test at 18:15 exposed two additional details.
The drives accepted asynchronous (`--immed`) START commands but remained in
the enable-spinup-required state. A subsequent readiness check through a
zero-capacity `/dev/sdX` device blocked in the kernel's `bdev_open`. Synchronous
`sg_start --start /dev/sgN` commands successfully started the drives; their
capacities became available at 18:17:20 and 18:17:54. The corrected script
resolves `/dev/sgN` from each stable WWN through sysfs and uses that control
device for both START and TEST UNIT READY. It no longer uses `--immed` or
opens zero-capacity block devices for these commands.

The second enclosure cold-start test at 18:47 confirmed that all four SAS
drives start automatically through the generic devices. However, a SCSI
rescan updated capacity without creating their partition devices, so the
script timed out safely at 18:51:48. A non-destructive kernel partition-table
reread created the missing partition immediately. The script now uses
`blockdev --rereadpt` after SCSI readiness and nonzero capacity are established,
and only when the expected partition is missing. This reads the existing
partition table; it does not modify it. See the
[util-linux blockdev manual](https://kernel.googlesource.com/pub/scm/utils/util-linux/util-linux/+/refs/tags/v2.41.1/disk-utils/blockdev.8.adoc).

## Installed configuration

- Script: `/mnt/app_pool/admin/hdd-startup/hdd-startup.py`, owned by root, mode 0700.
- Log: `/mnt/app_pool/admin/hdd-startup/hdd-startup.log`, with three rotated
  backups of up to 256 KiB each. Messages also go to syslog as `hdds-startup`.
- Existing Init/Shutdown task ID 1 was updated through `midclt` to run the
  script as PREINIT. The task has a 600-second timeout, with an external
  540-second process timeout and a ten-second kill grace period.
- Cron Job ID 187 runs the same file with `--monitor` every minute as root,
  with the same outer process timeout. It is registered through the TrueNAS
  Cron Jobs API and is also stored in the configuration database.
- The task and command are stored in TrueNAS's configuration database. The
  script lives on the separate, unencrypted `app_pool`, which is mounted
  before PREINIT. OS upgrades do not replace that data-pool file. No systemd
  units, OS packages, firmware, or drive mode pages were modified.
- `/root/sas-spinup.sh` is retained but is no longer scheduled.

The script checks the registered pool name/GUID and does nothing if the pool
is already healthy and mounted. Otherwise, it waits up to approximately four
minutes for all eight known members. It addresses drives by WWN, sends
sequential synchronous START requests only to the four SAS disks that need attention,
checks SCSI readiness, rescans capacity, and explicitly rereads the existing
partition table when needed. All eight
expected partition UUIDs must be on their expected drives and have matching
ZFS pool labels with the original four top-level vdevs before import is attempted.

Recovery invokes the same `pool.import_on_boot` job used by TrueNAS's
`ix-zfs.service`. It preserves pool IDs and schedules and runs the native
mount/unlock/configuration hooks. The job logs an innocuous already-imported
error for `app_pool`. During live recovery, running NFS/SMB services are
reloaded afterward; during PREINIT, TrueNAS starts services normally.

The script never exports, creates, destroys, formats, clears labels, or rewinds
a pool. The startup mode refuses recovery if other configured pools are missing, if the
target is already imported with unhealthy status, or if its identity changes.
An intentional later export stays exported: the periodic mode never imports.

`pool.import_on_boot` is an internal API, so future API changes still need
review after major upgrades. A missing/changed API fails visibly without
falling back to destructive operations. Persistence across upgrades does not
guarantee compatibility with every future TrueNAS release.

After replacing a member disk, deliberately update the WWN/partition mapping
in the script. Otherwise recovery will refuse to import a pool missing an
expected member. This intentionally does not automate degraded imports.

## Enclosure-only outages while the server is running

The periodic monitor first observes a healthy pool to arm itself on each
boot. Healthy checks read cached ZFS status and do not issue spin-up commands,
read all drive labels, or clear error counters. The latest poll time and retry
state are in `runtime-state.json` beside the script.

For a suspended pool, or multiple enclosure members simultaneously marked
unavailable/removed, it waits for all eight original members, starts SAS
drives through their SCSI generic devices, verifies capacity, partition UUIDs,
and pool labels, and rechecks pool identity and topology. It then saves the
original status/counters as `outage-<UTC timestamp>.json` and executes only:

```sh
zpool clear HDDs
```

This resumes a suspended pool once its devices can be accessed, as documented
by [OpenZFS](https://openzfs.github.io/openzfs-docs/man/master/8/zpool-clear.8.html).
There are no rewind flags, exports, or imports in runtime mode. It verifies
the recovered pool/mounts and reloads running NFS/SMB services.

The monitor refuses intentional OFFLINE members, changed topology, known
data/checksum errors, and isolated disk faults. It makes at most one clear
attempt before requiring ten minutes of observed healthy operation, with at
most three attempts per rolling 24 hours. A failed clear requires diagnosis;
it does not repeatedly reset counters. The daily attempt history survives
reboots. An unavailable enclosure is rechecked on later scheduled runs.

Startup and runtime modes share an exclusive lock. Child commands inherit
the lock so a command stuck in kernel I/O continues to block duplicate
recovery processes even if the outer timeout terminates Python. Runtime
checks skip system startup/shutdown. Scripts and monitoring state are on the
separate application SSD, so loss of the JBOD does not make them inaccessible.

Detection normally takes up to one minute plus disk spin-up/recovery time.
The monitor cannot restore power to an enclosure, repair failed hardware, or
guarantee applications retry I/O errors they received during an outage. The
existing pool `failmode=continue` setting was left unchanged.

## 25.10.8 update and app upgrades on 12 November 2026

The user authorized updating TrueNAS and then its three catalog apps. The
pre-update check found HDDs, app_pool, and boot-pool ONLINE; the recovery
scripts matched this checkout and all three scheduled tasks remained enabled.
Source comparison between 25.10.7 and 25.10.8 found no changes to the native
pool-import routine, startup-task handling, or cron code used by the fix.

Before installation, `config.save` produced a configuration archive including
the secret seed and root authorized keys. Its SQLite integrity check passed.
The protected server backup is
`/mnt/app_pool/admin/hdd-startup/backup-20261112-1030-pre-25.10.8/`.
An identical private copy is on the workstation at
`/home/riley/.config/truenas-control/backups/truenas-25.10.7-before-25.10.8-20261112.tar`.
These files contain secrets and must stay private. The server backup also
contains app configuration, task records, the recovery scripts, and container
states. Boot environment `25.10.7` was marked `keep=true`.

Recursive snapshots named `pre-truenas-25.10.8-20261112` were created for
`app_pool/apps`, `app_pool/ix-apps/app_mounts`, and
`app_pool/ix-apps/app_configs`. These are local recovery points, not independent
backups of all application data.

The supported `update.run` job 64149 completed successfully and selected
25.10.8 for the next boot. A clean reboot was requested at 10:35:20 AWST.
By 10:45 the server had not returned over SSH or ping, including over the
workstation's Wi-Fi path. A wake packet at 10:41:01 did not restore access,
and LAN discovery did not locate the server's MAC at another address. The
enclosure stayed powered on. The user found the server powered on with no
display, briefly pressed its power button to shut it down, and started it
again. The new boot began at 11:06:04 and ran TrueNAS 25.10.8 with kernel
6.12.113. The retained environment's journal reached the reboot target at
10:35:36; it does not establish where the first restart stalled. Its final
entries are saved as `previous-shutdown-journal.txt` in the backup directory.

HDDs imported automatically. At 11:06:55 the unchanged startup script
confirmed the pool was already healthy, and the runtime monitor armed at
11:07:05. All eight members had zero reported read/write/checksum errors;
pool ID 18 was unchanged. All pools were healthy, the media dataset mounted,
NFS/SMB were active, workstation NFS access passed, and startup task 1,
wake task 3, and cron task 187 remained enabled. `Wake-on: g` also persisted.
This was a boot with the enclosure powered; a cold enclosure test on the
new kernel has not been performed.

After these checks, catalog sync and the supported `app.upgrade` calls
completed successfully, with `snapshot_hostpaths=true` for each app:

| App | Previous software/catalog version | Updated software/catalog version | Job |
| --- | --- | --- | --- |
| Portainer | 2.45.2 / 1.7.14 | 2.45.3 / 1.7.21 | 116 |
| HexOS | 1.4.3 / 1.4.4 | 1.4.8 / 1.4.8 | 127 |
| Tailscale | 1.102.5 / 1.4.17 | 1.104.4 / 1.4.26 | 138 |

All three apps reported RUNNING with no remaining catalog or image updates.
Portainer's HTTP/HTTPS status APIs returned 2.45.3, Tailscale reported a
running backend and online identity, and all three containers had zero
restarts. Host-path snapshots and HexOS ix-volume rollback snapshots were
verified. All 19 containers that were running before the update were still
running afterward. `gluetun` was unhealthy before the update and remained so;
no unrelated VPN configuration was changed. Before/after app configuration,
container states, and verification results are stored in the private backup
directory. The previous boot environment and recovery snapshots were retained.

## Portainer migration and homepage on 12 November 2026

After the OS/app upgrades, Tailscale and HexOS moved to Portainer-managed
Compose stacks in environment `local` (endpoint 3):

| Service | Portainer stack | Container | Update image |
| --- | --- | --- | --- |
| Tailscale | `tailscale` (8) | `tailscale-tailscale-1` | `ghcr.io/tailscale/tailscale:stable` |
| HexOS | `ix-hexos` (9) | `ix-hexos-hexos-1` | `eshtek/hexos:latest` |

Their native TrueNAS registrations were removed with image and ix-volume
deletion disabled. Only Portainer remains in the TrueNAS Apps list. Do not
install a second Tailscale or HexOS instance alongside these stacks. Both
containers use `restart: unless-stopped`; stack definitions and data live on
`app_pool`, not the TrueNAS boot filesystem.

Tailscale retains `/mnt/app_pool/apps/appdata/tailscale`, the same device
identity, address `100.86.58.121`, and advertised route `192.168.1.0/24`.
Its old enrollment key was omitted from the new configuration; authenticated
state persists in that directory with `TS_AUTH_ONCE=true`. The image uses the
[recommended stable tag](https://tailscale.com/docs/features/client/update).
The migrated client remained at 1.104.4 and passed health and workstation
Tailscale ping checks.

HexOS was stopped before copying `hexos_data` and `netbird_state` into
`/mnt/app_pool/apps/appdata/hexos/`, preserving permissions and checking file
checksums. SQLite `quick_check` passed. Its TrueNAS API credentials, host
identity, network settings, pool mounts, and Docker access were retained.
The `ix-hexos` project and `hexos` service names are deliberately preserved:
the installed agent's filesystem guard looks up these exact Compose labels.
Logs confirmed reconnection to both TrueNAS and the HexOS cloud, and its
local HTTP interface on port 43706 returned 200. The privileged
`hexos-host-exec` helper remains under HexOS's control. This verifies the
installed version's connections, not every HexOS operation or compatibility
with future releases. Catalog configuration changes are no longer applied
automatically to these two Portainer stacks.

Watchtower had been stopped since 6 September with no restart policy. Its
service in `server-stack` (2) now uses `nickfedor/watchtower:latest`, version
1.24.0 at deployment, and `restart: unless-stopped`. The original
[containrrr project is archived](https://github.com/containrrr/watchtower);
the [maintained fork](https://github.com/nicholas-fedor/watchtower) negotiated
Docker API 1.51 successfully. Updates are scheduled for **04:00 Australia/Perth
daily** (`0 0 4 * * *`), first scheduled for 13 November.

Selection permits the `server-stack` project or an explicit
`com.centurylinklabs.watchtower.enable=true` label, which both migrated apps
have. Existing `enable=false` exclusions for Pi-hole, Traefik, and the
homepage remain effective. Portainer and `hexos-host-exec` are also explicitly
excluded. Stopped containers are neither checked nor revived; restarting
containers are included. The stop timeout is 60 seconds. Old images and
volumes are not automatically deleted, and no notification destination is
configured. See the fork's
[container selection rules](https://watchtower.nickfedor.com/v1.24.0/getting-started/container-selection/).
Future services outside `server-stack` need an explicit enable label to opt in.

A monitor-only selection check scanned the intended 14 running apps with
zero failures; Watchtower itself subsequently became the fifteenth eligible
container. A separate registry check scanned Tailscale and HexOS with zero
failures or updates. No newer image was available for those two, so an actual
Watchtower replacement was not exercised. The scheduled Watchtower container
is healthy and logged the correct next run time.

Redeploying `server-stack` restarted several media containers with the same
images and environment settings. Homarr's active `/appdata` database was in
an anonymous Docker volume despite its older host-path mappings. The
redeploy allocated a fresh volume; the original was retained and reattached.
The stack now explicitly references that original volume as external
`homarr_appdata`; FlareSolverr's original `/config` volume is similarly
declared as `flaresolverr_config`. Both identities were verified after
recreation, and private copies were archived. All 20 containers run;
Gluetun's pre-existing unhealthy status remains. Jellyfin and Homarr HTTP
checks returned 200.

The `https` stack (7) stores the homepage as inline Compose configuration
`homepage_html`. All 14 links now specify `target="_blank"` and
`rel="noopener noreferrer"`; destinations and styling are unchanged.
The change was saved through Portainer, the homepage container was
recreated to apply the embedded configuration, and the public HTTPS page
was checked. Edit this stack configuration for future changes rather than
editing the container's generated HTML.

Private migration records are under
`/mnt/app_pool/admin/portainer-migration-20261112/` (root-only). They include
original app settings, before/final Compose files, inspections, verification
logs, Tailscale state, and copies of the original Homarr/FlareSolverr volumes.
Snapshots `app_pool/apps@pre-portainer-migration-20261112` and recursive
`app_pool/ix-apps/app_mounts/hexos@pre-portainer-migration-20261112` were taken.
The original HexOS ix-volumes remain intact. An archive also includes the
quiescent original HexOS data and is copied privately to the workstation's
`~/.config/truenas-control/backups/portainer-migration-20261112.tar.gz`.
These archives contain credentials; keep them outside version control.

For rollback, stop Watchtower first and stop the affected Portainer stack
before starting any replacement. Reinstall a native app using its saved
configuration and the current persistent data, or redeploy the saved
Portainer configuration with a known-good image. HexOS's native catalog app
was `ix-app`, not a catalog entry named `hexos`; its original creation
payload is saved privately. Remove the Portainer stack without deleting
volumes before reusing its project name. Never run two instances against
the same state. Old snapshots/data copies are fallback points and may lack
subsequent changes; do not roll back the whole `app_pool/apps` dataset merely
to restore one application.

## Verification and operation

Run the isolated tests from the repository root using the locked Python environment:

```sh
nix shell --impure --file scripts/truenas/control-python.nix --command python3 -m unittest discover -s scripts/truenas -p 'test_*.py'
```

Live recovery succeeded from the original failed state on 28 October 2026.
All eight members and all four mirrors became ONLINE with zero reported
read/write/checksum errors and no known data errors. The last completed scrub
reported zero errors on 18 October. `/mnt/HDDs` and
`/mnt/HDDs/server_media` mounted from the expected datasets. Pool ID 18, scrub
schedules, and both NFS/SMB share configurations were unchanged. Both NFS
exports were verified after reloading NFS.

The first cold-start test did not recover unattended: it exposed the SCSI
command issues described above. After the synchronous starts, recovery
completed at 18:18:46, and the NFS/SMB services were reloaded.

The second cold-start test also needed intervention: spin-up succeeded, but
partition detection needed the additional reread described above. After
validating that operation on one member, the revised script detected the
remaining three partitions and recovered HDDs at 18:54:09. All eight members
were ONLINE with zero read/write/checksum errors, the pool retained ID 18,
both datasets were mounted, and NFS/SMB were running with the expected exports.
The third enclosure cold-start test **passed unattended**. After the user
power-cycled the enclosure and started the server, PREINIT began at 19:07:48.
All four SAS disks initially reported enable-spinup-required. Sequential
starts, capacity rescans, and explicit partition rereads completed; all eight
members were ready at 19:08:57. The native import restored HDDs at 19:09:06,
about 78 seconds after recovery began. No manual disk or pool command was
needed. Read-only inspection afterward confirmed all eight members ONLINE,
zero errors, unchanged pool ID 18, correct mounts, running NFS/SMB, and both
NFS exports. The workstation successfully read the media share over NFS.
The scheduled runtime monitor armed automatically on this boot at 19:10.

A further enclosure cold-start test passed after the Smart Life relay test
and BIOS change. The server booted at 20:00:39, and recovery began at
20:03:05. All four SAS members again needed START commands, capacity rescans,
and partition rereads. The pool and datasets were verified online at
20:04:24, approximately 79 seconds after recovery began, with no manual
storage command. Inspection confirmed all eight members ONLINE, zero
read/write/checksum errors, unchanged pool ID 18, both mounts, active NFS/SMB,
a successful workstation NFS directory read, and the runtime monitor armed
on the new boot. Installed script hashes matched this checkout.

Executing the registered PREINIT task on a healthy pool correctly took the
no-op path. Thirty-five isolated tests passed, including cold-drive command
selection, missing members, wrong labels, identity/topology changes, missing
mounts, failed calls, intentional export/offline protection, runtime outage
recovery, retry limits, and capacity-to-partition detection. Regression tests
also verify that zero-capacity block devices are never opened for partition
rereads and a failed reread cannot bypass member readiness. Tests simulate fault states using the observed
OpenZFS JSON schema and never access real storage. The monitor was also run
against the healthy server, and a concurrent invocation safely skipped its
work while the lock was held. No live enclosure power loss was induced.
TrueNAS cron executions at 18:27, 18:28, and 18:29 completed successfully with
the healthy pool; the deployed script and runbook hashes matched this checkout.

Run on the TrueNAS server as root:

```sh
# Inspect readiness; no drive start, rescan, or import.
python3 /mnt/app_pool/admin/hdd-startup/hdd-startup.py --check

# Manually run the same recovery when required.
timeout --kill-after=10s 540s python3 /mnt/app_pool/admin/hdd-startup/hdd-startup.py

# Run one guarded runtime check; this will not import an exported pool.
timeout --kill-after=10s 540s python3 /mnt/app_pool/admin/hdd-startup/hdd-startup.py --monitor

# Inspect the latest result.
tail -n 60 /mnt/app_pool/admin/hdd-startup/hdd-startup.log
cat /mnt/app_pool/admin/hdd-startup/runtime-state.json
zpool status -v HDDs
findmnt --mountpoint /mnt/HDDs/server_media
exportfs -v
```

A reboot test requires an approved interruption to applications and shares.
A warm reboot may not reproduce the enclosure's cold power-on behavior; a
planned cold-start test is needed to validate that separately. Do not pull
power from an active pool to test this.

## Backup and rollback

The root-only directory
`/mnt/app_pool/admin/hdd-startup/backup-20261028/` contains:

- The previous startup task and script.
- A consistent SQLite backup of the TrueNAS configuration and its secret seed.
- Original pool, scrub, NFS, and SMB records for comparison.
- `unmounted-HDDs-files/`, preserving two small database files created under
  the unmounted `/mnt/HDDs` path by applications during the outage. They were
  not merged into or substituted for the actual pool's files.

Keep this backup private: it contains configuration secrets. To disable only
this workaround without touching the data pool:

```sh
midclt call initshutdownscript.update 1 '{"enabled": false}'
midclt call cronjob.update 187 '{"enabled": false}'
```

The original task JSON is available for deliberate restoration, but it calls
the broken script and is not recommended. Keep another copy of the script
alongside regular TrueNAS configuration backups: a configuration download
does not include arbitrary scripts stored on data pools.

## Separate enclosure event

On 23 October at 04:55:02, the previous boot's kernel log recorded multiple
JBOD disks disappearing together and HDDs becoming suspended. That is evidence
of an enclosure/power/link interruption, not just a boot-import timing issue.
The logs alone do not identify which component caused it. Automatic recovery
does not repair a power supply, cable, expander, or controller fault. If this
was not an intentional enclosure shutdown or known power loss, investigate
those shared components before relying on unattended operation.

## Wake-on-LAN

The server's ASUS TUF GAMING B560M-PLUS WIFI motherboard uses a Realtek
RTL8125B Ethernet adapter, currently `enp4s0`, MAC `fc:34:97:bc:37:4d`.
The driver reported `Supports Wake-on: pumbg`, but wake was initially disabled
(`Wake-on: d`). Enabling magic-packet wake changed that to `Wake-on: g` and
the PCI device's `power/wakeup` state to `enabled`.

TrueNAS POSTINIT task ID 3 runs
`/usr/bin/timeout 20s /bin/sh /mnt/app_pool/admin/hdd-startup/enable-wol.sh`.
The root-owned script lives on `app_pool` alongside the recovery script,
finds the physical interface by MAC, enables magic-packet wake, and verifies
the setting. The task persists in the TrueNAS configuration database.
It does not change the interface's address, speed, routing, or link state.

From another computer on the same LAN, run [wake-server.py](wake-server.py).
It sends three standard magic packets to `192.168.1.255:9` for the server's MAC.
On this NixOS workstation:

```sh
nix shell nixpkgs#python3 --command python3 /etc/nixos/scripts/truenas/wake-server.py --source 192.168.1.70
```

The optional source address selects the wired interface on this workstation,
which also has Wi-Fi on the same subnet. Packet capture on the server
confirmed delivery of the correct 102-byte payload at 19:13:01. Packet
delivery while running alone does not prove wake from shutdown; that test
is tracked separately. Keep mains power supplied to the server for standby
power, and power the enclosure before waking the server.

The first shutdown-to-wake test failed. The server was cleanly shut down at
19:13:23 with `Wake-on: g` verified immediately beforehand. Three packets
were sent at 19:14:26 and again at 19:17:27, but the server did not return.
The user confirmed it remained physically powered off. Firmware wake
configuration is the next check; the user was asked to enable PCI-E wake,
disable ErP, and boot the server manually. The user then started it using
the power button without changing BIOS settings. On that boot, task 3 ran
at 19:20:46 and automatically restored `Wake-on: g` and PCI wake `enabled`.
HDDs imported normally and the recovery script correctly did nothing.
Thus software persistence across reboot is verified. After the Smart Life
control test, the user confirmed saving **Power On By PCI-E = Enabled** and
**ErP Ready = Disabled**, and reported the server booting. A new
shutdown-to-wake test then succeeded: TrueNAS completed its power-off target
at 20:05:31, wake packets were sent from wired address `192.168.1.70` at
20:06:43, and the new kernel boot began at 20:07:06. SSH was observed available
at 20:08:44. The enclosure remained powered throughout this test, and no
manual startup was requested. HDDs imported normally; the startup helper
confirmed it was already healthy at 20:07:54. Post-wake inspection verified
all eight members ONLINE with zero reported errors, unchanged pool ID 18,
the media dataset mounted, active NFS/SMB, successful workstation NFS access,
`Wake-on: g`, and the runtime monitor armed at 20:09. Startup task 1, wake
task 3, and every-minute monitor 187 remained enabled. The NAS was left running.

If firmware prevents wake, ASUS documents **Advanced > APM Configuration >
Power On By PCI-E > Enabled** in its
[Wake-on-LAN guide](https://www.asus.com/support/faq/1045950/).
Also set **ErP Ready > Disabled**: the
[Intel 500-series BIOS manual, pages 42–43](https://dlcdnets.asus.com/pub/ASUS/mb/13MANUAL/PRIME_PRO_TUF_GAMING_Intel_500_Series_BIOS_EM_WEB_EN.pdf)
states that enabling ErP disables the other PME wake options.
Firmware settings cannot be confirmed merely from `ethtool` output.
For access from outside this LAN, send the packet from an always-on local
device reached over a VPN; the Tailscale app on the powered-off NAS cannot
receive it.

To disable the persistent setting, disable task 3 and run
`ethtool -s enp4s0 wol d` on the server. The protected backup directory also
contains `freenas-after-wol.db`, a consistent configuration backup including
the storage and wake tasks.

## Enclosure smart switch

Local enclosure power control is configured and verified on this workstation.
The user moved the **Arlec PC191HA**, named **drive bay**, from Grid Connect
to Smart Life and approved Tuya's QR authorization. No Home Assistant
installation or Tuya Developer project is required. Read-only TinyTuya
discovery confirmed the same device identity and address after re-pairing:

- Device ID: `bfbd4383ab65aafaaf3gfw`
- LAN address at discovery: `192.168.1.144`
- Protocol: `3.3`
- Broadcast product key: `keym9qkuywghyrvs`

The address shown in Grid Connect was the public internet address; local
control uses the LAN address. Another discovered Tuya device at `.184` is
not the drive bay and was not contacted for control.

For supported Tuya devices, [TinyTuya](https://github.com/jasonacox/tinytuya)
can control power locally using a device ID, LAN address, protocol version,
and local key. The [Tuya Local device definition](https://github.com/make-all/tuya-local/blob/main/custom_components/tuya_local/devices/smartplugv2_energy.yaml)
lists PC191HA models and defines relay datapoint 1. The official
[Home Assistant Tuya integration](https://www.home-assistant.io/integrations/tuya/)
expects a device paired in Tuya Smart or Smart Life. Keep credentials outside
this repository. Power control must run on a device available while the NAS
is off; do not use absence of ping alone as permission to cut enclosure power.

The workstation helper [drive-bay.py](drive-bay.py) is **authenticated and
verified against the live plug**. Its private configuration
is `/home/riley/.config/truenas-control/drive-bay.json`, mode 0600, outside
this repository. It contains the inventory and the 16-byte local key obtained
with the user's Smart Life approval. A reset/re-pair can change the key and
interrupt the enclosure's power. Back up this file privately; it is not part
of the TrueNAS configuration backup or this checkout.

Initially, the user had neither a local key nor a Tuya Developer project. Their Grid
Connect app exposed a User Code and QR scanner. An alternative to a
developer project was prepared in [authorize-drive-bay.py](authorize-drive-bay.py),
using Tuya's sharing SDK and the public integration client used by
[Tuya Local](https://github.com/make-all/tuya-local/blob/main/custom_components/tuya_local/cloud.py).
Tuya successfully issued a QR code, but Grid Connect rejected the scan with
"please use the designated APP to scan the code to log in". No key was
retrieved through Grid Connect. The official-app route is Smart Life/Tuya Smart;
issuing a QR code did not prove compatibility with Grid Connect.
The user authorized moving only the drive bay plug to Smart Life.
At 19:45 on 28 October, all eight HDDs members were ONLINE with no reported
errors and no running middleware jobs. The authorized `system.shutdown`
request was accepted; TrueNAS announced power-off and disconnected at
19:46:05. The user subsequently confirmed physical shutdown. Using the new
Smart Life User Code and phone approval, the helper retrieved the confirmed
plug's key and removed the temporary login files. Authenticated local status
returned ON. A controlled OFF/ON test with the NAS physically off verified
both relay states and left the enclosure ON at 19:55. No power was cut to
an active pool. The user was then asked to start the NAS and check the two
BIOS wake settings before another Wake-on-LAN test.
Read-only inspection also returned datapoint 38 = `on`, the configured
power-restoration state in the device definition linked above. The plug is
already configured to turn its outlet on when mains power returns. This
setting was not changed; a physical mains interruption was not tested.

```sh
# Prompts privately for the app User Code and creates a private QR image.
nix shell --impure --file scripts/truenas/control-python.nix --command python3 scripts/truenas/authorize-drive-bay.py begin
# After scanning/approving on the phone, retrieve only the confirmed plug.
nix shell --impure --file scripts/truenas/control-python.nix --command python3 scripts/truenas/authorize-drive-bay.py finish
```

The phone authorization may be labelled Home Assistant/Tuya, but no Home
Assistant installation is needed by the helper. It queries only the confirmed
device ID, saves only its local key to the existing private configuration,
and revokes the temporary cloud session afterward. It never sends relay or
pairing commands. Pending QR material is private and removed after an
authenticated attempt. Three mocked tests verify that pending approval cannot
retrieve a key, a different device's key cannot be stored, and successful
retrieval preserves private permissions and revokes the temporary session.
Grid Connect cannot use this QR login. Do not reset or re-pair the plug
while the NAS is running; verify physical shutdown before proceeding.

Run from this checkout:

```sh
nix shell --impure --file scripts/truenas/control-python.nix --command python3 scripts/truenas/drive-bay.py status
nix shell --impure --file scripts/truenas/control-python.nix --command python3 scripts/truenas/drive-bay.py on
```

The Nix expression uses this repository's locked nixpkgs and does not change
the workstation's system configuration. The `on` command first authenticates
and checks the relay; an already-on plug receives no power command. `off`
requires an explicit `--server-shut-down` assertion and also refuses if the
NAS responds on SSH/HTTP/HTTPS. That assertion means the operator has actually
verified a clean shutdown; it must never be inferred from a network timeout.
There is no automatic power-cycle function. Six mocked safety tests passed;
running `status` without the key failed locally before any device request.
The live status, OFF, and ON checks also passed after authorization. The
TrueNAS runtime recovery monitor remains independent of the smart plug:
it attempts recovery after enclosure power returns, and never cuts power.

If DHCP changes the plug's address, update the private configuration after
matching its device ID, or reserve its address at the router. Credentials
are never stored in the TrueNAS startup task or this repository.
