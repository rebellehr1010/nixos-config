#!/usr/bin/env python3
"""Control the confirmed 'drive bay' plug using its privately stored local key."""

import argparse
import errno
import json
import os
from pathlib import Path
import socket
import sys
import time

DEVICE_ID = "bfbd4383ab65aafaaf3gfw"
CONFIG = Path.home() / ".config/truenas-control/drive-bay.json"


def read_config(path):
    info = path.stat()
    if info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise RuntimeError("The credential file must be owned by you and private (chmod 600)")
    config = json.loads(path.read_text())
    if config.get("device_id") != DEVICE_ID:
        raise RuntimeError("Device ID does not match the confirmed drive bay plug")
    key = config.get("local_key", "")
    if not isinstance(key, str) or len(key.encode()) != 16:
        raise RuntimeError(f"A 16-byte Tuya local key is required in {path}; no plug command was sent")
    if config.get("version") != 3.3:
        raise RuntimeError("Expected the discovered Tuya protocol 3.3; review changed firmware first")
    return config


def server_responds():
    for port in (22, 80, 443):
        try:
            with socket.create_connection(("192.168.1.71", port), timeout=1):
                return True
        except OSError as exc:
            if exc.errno == errno.ECONNREFUSED:
                return True  # A refusal still demonstrates a responding host.
            if not isinstance(exc, TimeoutError) and exc.errno not in (
                    errno.ETIMEDOUT, errno.EHOSTUNREACH, errno.ENETUNREACH):
                raise RuntimeError("Could not check the NAS; refusing power-off") from exc
    return False


def status(device):
    result = device.status()
    dps = result.get("dps", {}) if isinstance(result, dict) else {}
    if type(dps.get("1")) is not bool:
        raise RuntimeError("No valid authenticated relay status; check the local key and device address")
    return dps["1"]


def control(device, action, confirmed_shutdown=False):
    if action == "off":
        # Network silence cannot establish a safe shutdown. Require an explicit
        # operator assertion as well, then refuse if the NAS still responds.
        if not confirmed_shutdown:
            raise RuntimeError("Power-off requires --server-shut-down after verifying a clean NAS shutdown")
        if server_responds():
            raise RuntimeError("The NAS still responds; refusing enclosure power-off")
    before = status(device)
    if action == "status":
        return before
    desired = action == "on"
    if before != desired:
        device.set_status(desired, switch=1)
        time.sleep(1)
        if status(device) != desired:
            raise RuntimeError("Plug did not confirm the requested state")
    return desired


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("status", "on", "off"))
    parser.add_argument("--config", type=Path, default=CONFIG)
    parser.add_argument("--server-shut-down", action="store_true",
                        help="Assert that you verified the NAS has shut down cleanly; required for off")
    args = parser.parse_args()
    try:
        config = read_config(args.config)
        import tinytuya
        device = tinytuya.OutletDevice(DEVICE_ID, config["address"], config["local_key"],
                                     version=config["version"], connection_timeout=3)
        device.set_socketRetryLimit(1)
        on = control(device, args.action, args.server_shut_down)
        print(json.dumps({"name": "drive bay", "address": config["address"], "on": on}))
    except (OSError, ValueError, KeyError, RuntimeError) as exc:
        print(f"Drive bay: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
