#!/usr/bin/env python3
"""Recover riley-server's existing HDDs pool after late SAS disk spin-up.

Run from a TrueNAS PREINIT command stored in its configuration database.
Keep this file on app_pool, which imports before PREINIT independently of HDDs.
No export, creation, formatting, label clearing, rewind, or database edits.
"""

import argparse
import fcntl
import json
import logging
from logging.handlers import RotatingFileHandler, SysLogHandler
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time

POOL = "HDDs"
GUID = "9538639308343860317"
# WWN -> partition UUID. Update deliberately after replacing a pool member.
DISKS = {
    "500605ba00ad1170": "987ae58e-9eb4-4022-93b3-05206ed7d50e",
    "500605ba00ad8654": "74b9d91c-e8c6-407e-8538-5730be4dd01b",
    "50000c0f013a0c14": "4cce9651-191c-4f13-a701-6b5fc3296114",
    "50000c0f013741d4": "96937845-0534-4501-b71b-87895eaedac7",
    "50000c0f01ff26d8": "a9ab6731-2a3c-4b1c-820e-c9f8181e582c",
    "50000c0f01ff1ce4": "639ce548-8cbd-4695-83f2-412a5c3633a5",
    "50014ee2bc38a2e6": "88c84241-255d-48ff-ab78-0dceda1a9d8e",
    "500605ba00ad869c": "2c3efc26-a2a5-418f-93c7-7aa0c174bb6f",
}
SAS = {wwn for wwn in DISKS if wwn.startswith("50000c0f")}
ENCLOSURE_PARTS = {part for wwn, part in DISKS.items() if wwn != "50014ee2bc38a2e6"}
LOG = logging.getLogger("hdds-startup")
LOCK_FD = None
RUNTIME_STATE = Path(__file__).resolve().with_name("runtime-state.json")


def run(args, timeout=20, check=True):
    # A child stuck in uninterruptible kernel I/O must retain the lock even if
    # the outer timeout kills Python, preventing accumulating cron processes.
    inherited = (LOCK_FD,) if LOCK_FD is not None else ()
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, pass_fds=inherited)
    if check and result.returncode:
        raise RuntimeError(f"{args!r} exited {result.returncode}: "
                           f"{result.stdout.strip()} {result.stderr.strip()}")
    return result


def api(method, *args, job=False, timeout=30):
    cmd = ["midclt", "call"] + (["--job"] if job else [])
    result = run(cmd + [method] + [json.dumps(arg) for arg in args], timeout)
    output = result.stdout.strip()
    if output in ("", "None", "null"):
        return None
    if output in ("True", "False"):
        return output == "True"
    return json.loads(output)


def configured_pool():
    pools = api("pool.query")
    matches = [p for p in pools if p["name"] == POOL and str(p["guid"]) == GUID]
    if len(matches) != 1:
        raise RuntimeError("Expected pool name/GUID is not registered in TrueNAS; refusing recovery")
    return matches[0], pools


def imported_pools():
    result = run(["zpool", "list", "-H", "-o", "name,guid,health"])
    return {row[0]: (row[1], row[2]) for line in result.stdout.splitlines()
            if len(row := line.split()) == 3}


def already_online():
    pools = imported_pools()
    if POOL not in pools:
        return False
    if pools[POOL] != (GUID, "ONLINE"):
        raise RuntimeError(f"Pool is already imported with unexpected identity/health: {pools[POOL]}; "
                           "leaving it intact for diagnosis")
    return True


def block_size(path):
    try:
        if not stat.S_ISBLK(path.stat().st_mode):
            return 0
        return int((Path("/sys/class/block") / path.resolve().name / "size").read_text())
    except (FileNotFoundError, ValueError):
        return 0


def scsi_device(dev):
    # Opening a zero-capacity /dev/sdX can block in bdev_open while the drive
    # waits for spin-up. SG devices bypass block-layer capacity revalidation.
    generic = list((Path("/sys/class/block") / dev.resolve().name / "device/scsi_generic").glob("sg*"))
    if len(generic) != 1:
        raise RuntimeError(f"Cannot resolve unique SCSI generic device for {dev}")
    return str(Path("/dev") / generic[0].name)


def disk_state(wwn, partuuid):
    dev = Path(f"/dev/disk/by-id/wwn-0x{wwn}")
    part = Path(f"/dev/disk/by-partuuid/{partuuid}")
    if not dev.exists():
        return False, "device not detected"
    tur = run(["sg_turs", "--verbose", scsi_device(dev)], timeout=10, check=False)
    if tur.returncode:
        return False, f"not ready (TUR {tur.returncode}): {tur.stderr.strip()}"
    if block_size(dev) == 0:
        return False, "kernel capacity is zero"
    if block_size(part) == 0:
        return False, "pool partition missing or zero capacity"
    # UUID must belong to this physical WWN, not merely exist elsewhere.
    parent = (Path("/sys/class/block") / part.resolve().name).resolve().parent.name
    if parent != dev.resolve().name:
        raise RuntimeError(f"Partition {partuuid} is on {parent}, not expected WWN {wwn}")
    return True, "ready with nonzero capacity and expected partition"


def refresh_kernel_disk(dev, partuuid):
    # SCSI rescan updates capacity but did not create partitions after the
    # real enclosure cold start. Explicitly reread the existing table too.
    (Path("/sys/class/block") / dev.resolve().name / "device/rescan").write_text("1\n")
    run(["udevadm", "settle", "--timeout=10"], timeout=15)
    part = Path(f"/dev/disk/by-partuuid/{partuuid}")
    # Never open a zero-capacity block device: that hung in bdev_open during
    # the first cold test. Caller has already established SCSI readiness.
    if block_size(dev) > 0 and block_size(part) == 0:
        LOG.info("Reading existing partition table from %s", dev)
        result = run(["blockdev", "--rereadpt", str(dev)], timeout=20, check=False)
        if result.returncode:
            LOG.warning("Partition reread failed for %s: %s", dev, result.stderr.strip())
        run(["udevadm", "settle", "--timeout=10"], timeout=15)


def wait_for_disks(check_only=False, timeout=240):
    deadline = time.monotonic() + timeout
    last_start, last_rescan, last_message = {}, {}, {}
    while True:
        pending = []
        for wwn, partuuid in DISKS.items():
            ready, reason = disk_state(wwn, partuuid)
            if last_message.get(wwn) != reason:
                LOG.info("%s: %s", wwn, reason)
                last_message[wwn] = reason
            if ready:
                continue
            pending.append(wwn)
            if check_only or time.monotonic() >= deadline:
                continue
            dev = Path(f"/dev/disk/by-id/wwn-0x{wwn}")
            if not dev.exists():
                continue
            now = time.monotonic()
            if wwn in SAS and reason.startswith("not ready") and now - last_start.get(wwn, -1000) >= 30:
                LOG.info("Requesting SAS start: %s", wwn)
                # These WD SAS drives accepted IMMED but remained in the
                # enable-spinup-required state. A synchronous START worked in
                # the actual cold-start test. Wait for it on the SG device.
                result = run(["sg_start", "--start", scsi_device(dev)], timeout=45, check=False)
                if result.returncode:
                    LOG.warning("SAS start %s: rc=%s %s", wwn, result.returncode, result.stderr.strip())
                last_start[wwn] = now
                # Stagger requests rather than starting four motors simultaneously.
                time.sleep(2)
            if reason in ("kernel capacity is zero", "pool partition missing or zero capacity"):
                if now - last_rescan.get(wwn, -1000) >= 15:
                    LOG.info("Re-reading capacity/partitions for %s", wwn)
                    refresh_kernel_disk(dev, partuuid)
                    last_rescan[wwn] = now
        if not pending:
            return
        if check_only or time.monotonic() >= deadline:
            raise RuntimeError(f"Disks not ready: {', '.join(pending)}; pool left untouched")
        time.sleep(5)


def validate_labels():
    for partuuid in DISKS.values():
        output = run(["zdb", "-l", f"/dev/disk/by-partuuid/{partuuid}"], timeout=20).stdout
        guids = set(re.findall(r"^\s*pool_guid:\s*(\d+)\s*$", output, re.M))
        names = set(re.findall(r"^\s*name:\s*'([^']+)'\s*$", output, re.M))
        top_vdevs = set(re.findall(r"^\s*vdev_children:\s*(\d+)\s*$", output, re.M))
        if guids != {GUID} or names != {POOL} or top_vdevs != {"4"}:
            raise RuntimeError(f"Unexpected ZFS pool labels on {partuuid}: {names}, {guids}")


def verify_available():
    if not already_online():
        raise RuntimeError("Boot import procedure returned but HDDs is still not imported")
    pool, _ = configured_pool()
    if pool["status"] != "ONLINE" or not pool["healthy"]:
        raise RuntimeError(f"TrueNAS has not reported a healthy ONLINE pool: {pool['status']}")
    for path, dataset in (("/mnt/HDDs", "HDDs"), ("/mnt/HDDs/server_media", "HDDs/server_media")):
        source = run(["findmnt", "-n", "-o", "SOURCE", "--mountpoint", path]).stdout.strip()
        if source != dataset:
            raise RuntimeError(f"{path} is not mounted from expected dataset {dataset}: {source}")
    LOG.info("Verified HDDs ONLINE in ZFS and TrueNAS; root and server_media datasets mounted")


def refresh_live_shares():
    # Boot hooks generate configuration; a live recovery also needs a reload.
    # During PREINIT leave service startup to TrueNAS's normal boot ordering.
    if not api("system.ready"):
        return
    for service in api("service.query", [["service", "in", ["nfs", "cifs"]]]):
        if service["state"] == "RUNNING":
            LOG.info("Reloading %s after live pool recovery", service["service"])
            api("service.control", "RELOAD", service["service"], job=True, timeout=60)


def recover(check_only=False):
    pool, pools = configured_pool()
    if already_online():
        verify_available()
        LOG.info("Already available; no disk or pool changes needed")
        return
    if api("failover.licensed"):
        raise RuntimeError("Refusing automatic import on an HA system")
    imported = imported_pools()
    # The native boot job visits all registered pools. Only HDDs may be absent.
    others = [p["name"] for p in pools if p["name"] != POOL
              and imported.get(p["name"], (None,))[0] != str(p["guid"])]
    if others:
        raise RuntimeError(f"Other registered pools are absent ({others}); refusing broad boot import")
    wait_for_disks(check_only=check_only)
    validate_labels()
    if check_only:
        LOG.info("All eight members ready with correct pool labels; HDDs is ready for recovery")
        return
    # Recheck in case an administrator recovered/exported the pool while we waited.
    current, _ = configured_pool()
    if current["id"] != pool["id"]:
        raise RuntimeError("Pool registration changed during recovery; refusing import")
    if already_online():
        verify_available()
        return
    LOG.info("Retrying TrueNAS native boot import after all eight members are ready")
    # This is the same internal job as ix-zfs.service on TrueNAS 25.10.7.
    # It preserves pool registration/scrub settings and performs mount/unlock and
    # post-import service hooks. Already-imported pools are skipped after an
    # 'already exists' message. No custom zpool force/rewind/import-all fallback.
    api("pool.import_on_boot", job=True, timeout=180)
    verify_available()
    current, _ = configured_pool()
    if current["id"] != pool["id"]:
        raise RuntimeError("Unexpected change to TrueNAS pool registration")
    refresh_live_shares()


def pool_snapshot():
    # Avoid pool.query/zfs dataset operations until suspended I/O is resumed.
    # zpool status reads the cached pool configuration and vdev statistics.
    data = json.loads(run(["zpool", "status", "-j", "--json-int"], timeout=15).stdout)
    if data.get("output_version", {}).get("vers_major") != 0:
        raise RuntimeError("Unsupported zpool status JSON version")
    if not isinstance(data.get("pools"), dict):
        raise RuntimeError("Invalid zpool status JSON")
    return data["pools"].get(POOL)


def snapshot_devices(pool):
    if pool.get("name") != POOL or str(pool.get("pool_guid", pool.get("guid"))) != GUID:
        raise RuntimeError("Runtime pool identity mismatch")
    if any(pool.get(k) for k in ("logs", "special", "dedup", "l2cache", "spares")):
        raise RuntimeError("Runtime pool topology has additional device classes; review the inventory first")
    devices = []

    def walk(nodes):
        for node in nodes.values():
            if node.get("vdev_type") == "disk":
                devices.append(node)
            walk(node.get("vdevs", {}))

    walk(pool.get("vdevs", {}))
    paths = [d.get("path") for d in devices]
    expected = {f"/dev/disk/by-partuuid/{p}" for p in DISKS.values()}
    if len(devices) != len(expected) or set(paths) != expected:
        raise RuntimeError("Runtime pool topology differs from the eight expected members")
    return devices


def snapshot_healthy(pool, devices):
    return (pool["state"] == "ONLINE" and int(pool.get("error_count", 0)) == 0
            and all(d["state"] == "ONLINE" and all(int(d.get(k, 0)) == 0
                    for k in ("read_errors", "write_errors", "checksum_errors")) for d in devices))


def require_recoverable(pool, devices):
    if any(d["state"] == "OFFLINE" for d in devices):
        raise RuntimeError("A member was intentionally offlined; runtime recovery refused")
    if int(pool.get("error_count", 0)) > 0 or any(int(d.get("checksum_errors", 0)) for d in devices):
        raise RuntimeError("Data/checksum errors need investigation; refusing to clear them automatically")
    missing = [d for d in devices if d["state"] in ("UNAVAIL", "REMOVED", "CANT_OPEN")
               and Path(d["path"]).name in ENCLOSURE_PARTS]
    # Suspension can leave individual vdev states ONLINE, with I/O counters.
    # Otherwise require multiple enclosure members to be unavailable together.
    if pool["state"] != "SUSPENDED" and not (pool["state"] in ("DEGRADED", "UNAVAIL", "FAULTED")
                                             and len(missing) >= 2):
        raise RuntimeError("Not a suspended pool or multi-disk enclosure outage; refusing automatic clear")


def load_runtime_state():
    state = json.loads(RUNTIME_STATE.read_text()) if RUNTIME_STATE.exists() else {}
    now = time.time()
    attempts = [t for t in state.get("attempts", []) if now - t < 86400]
    boot_id = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    if state.get("boot_id") != boot_id:
        state = {"boot_id": boot_id, "armed": False, "attempted": False, "healthy_since": None}
    state["attempts"] = attempts
    return state


def save_runtime_state(state):
    temporary = RUNTIME_STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2) + "\n")
    temporary.replace(RUNTIME_STATE)


def monitor():
    system_state = run(["systemctl", "is-system-running"], timeout=10, check=False).stdout.strip()
    if system_state not in ("running", "degraded"):
        return  # Do not race boot or shutdown.
    state = load_runtime_state()
    pool = pool_snapshot()
    if time.time() - state.get("last_check", time.time()) > 120:
        state["healthy_since"] = None
    state["last_check"] = time.time()
    if pool is None:
        # Never reimport an intentionally exported pool from a periodic job.
        if state.get("armed"):
            LOG.warning("HDDs is no longer imported; runtime monitor disarmed (no automatic import)")
        state.update(armed=False, healthy_since=None)
        save_runtime_state(state)
        return
    devices = snapshot_devices(pool)
    if snapshot_healthy(pool, devices):
        if not state.get("armed"):
            configured_pool()
            LOG.info("Runtime monitor armed for healthy HDDs; checks every minute")
        state["armed"] = True
        if state.get("healthy_since") is None:
            state["healthy_since"] = time.time()
        # Require ten minutes of observed healthy operation before a new attempt.
        if time.time() - state["healthy_since"] >= 600:
            state["attempted"] = False
        save_runtime_state(state)
        return
    state["healthy_since"] = None
    save_runtime_state(state)
    if not state.get("armed"):
        raise RuntimeError("Runtime recovery requires a healthy baseline from this boot")
    require_recoverable(pool, devices)
    if state.get("attempted") or len(state["attempts"]) >= 3:
        raise RuntimeError("Runtime recovery retry limit reached; inspect logs and hardware before another clear")
    LOG.warning("Detected HDDs %s; waiting for all eight original members before resuming I/O", pool["state"])
    wait_for_disks()
    validate_labels()
    current = pool_snapshot()
    if current is None:
        state["armed"] = False
        save_runtime_state(state)
        LOG.warning("Pool exported during disk readiness checks; leaving it exported")
        return
    current_devices = snapshot_devices(current)
    if snapshot_healthy(current, current_devices):
        LOG.info("HDDs recovered while waiting; no clear needed")
        return
    require_recoverable(current, current_devices)
    # Preserve counters before clear. Also mark the attempt first so a crash or
    # hung ioctl cannot cause unbounded repeated clears on subsequent cron runs.
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    evidence = RUNTIME_STATE.with_name(f"outage-{stamp}.json")
    evidence.write_text(json.dumps({"before_wait": pool, "before_clear": current}, indent=2) + "\n")
    state["attempted"] = True
    state["attempts"].append(time.time())
    state["last_evidence"] = str(evidence)
    save_runtime_state(state)
    LOG.warning("Resuming existing HDDs with zpool clear (no rewind); prior counters saved to %s", evidence)
    run(["zpool", "clear", POOL], timeout=90)
    after = pool_snapshot()
    if after is None or not snapshot_healthy(after, snapshot_devices(after)):
        raise RuntimeError("Pool did not return to healthy ONLINE after one clear; manual diagnosis required")
    verify_available()
    refresh_live_shares()
    state["last_recovery"] = time.time()
    save_runtime_state(state)
    LOG.info("Runtime enclosure recovery completed; HDDs and its mounts are available")


def main():
    global LOCK_FD
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="Check readiness without starting disks or importing")
    modes.add_argument("--monitor", action="store_true", help="Check/resume an imported pool after a runtime enclosure outage")
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("Run as root")
    os.environ["PATH"] = "/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin"
    os.environ["LC_ALL"] = "C"
    os.umask(0o077)
    LOG.setLevel(logging.INFO)
    formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    stream = logging.StreamHandler(sys.stdout)
    stream.setFormatter(formatter)
    LOG.addHandler(stream)
    log = RotatingFileHandler(Path(__file__).resolve().with_suffix(".log"), maxBytes=262144, backupCount=3)
    log.setFormatter(formatter)
    LOG.addHandler(log)
    if Path("/dev/log").exists():
        syslog = SysLogHandler(address="/dev/log")
        syslog.setFormatter(logging.Formatter("hdds-startup: %(levelname)s %(message)s"))
        LOG.addHandler(syslog)
    with open("/run/hdds-startup.lock", "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            if not args.monitor:
                LOG.error("Another recovery process is active")
            return 0 if args.monitor else 1
        LOCK_FD = lock.fileno()
        try:
            if args.monitor:
                monitor()
            else:
                LOG.info("Starting %s on TrueNAS %s", "readiness check" if args.check else "recovery",
                         Path("/etc/version").read_text().strip())
                recover(args.check)
            return 0
        except Exception:
            LOG.exception("Recovery failed; no destructive fallback will be attempted")
            return 1


if __name__ == "__main__":
    sys.exit(main())
