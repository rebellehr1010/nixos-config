#!/usr/bin/env python3
"""Obtain only drive bay's local key using Tuya's phone-approved QR login.

Uses Tuya's sharing SDK and the public Tuya Local/Home Assistant integration
client with Smart Life / Tuya Smart. Grid Connect rejected this login route.
No pairing or relay commands are sent.
Authentication tokens and keys are never printed or stored in this checkout.
"""

import argparse
import getpass
import json
import logging
import os
from pathlib import Path
import sys
import time

import qrcode
from tuya_sharing import LoginControl
from tuya_sharing.customerapi import CustomerApi, CustomerTokenInfo, SharingTokenListener
from tuya_sharing.user import UserRepository

CLIENT = "HA_3y9q4ak7g4ephrvke"
SCHEMA = "haauthorize"
DEVICE_ID = "bfbd4383ab65aafaaf3gfw"
DIRECTORY = Path.home() / ".config/truenas-control"
PENDING = DIRECTORY / "tuya-login.json"
QR = DIRECTORY / "tuya-login.png"
CONFIG = DIRECTORY / "drive-bay.json"


def write_private(path, data):
    temp = path.with_suffix(path.suffix + ".tmp")
    with open(temp, "w", opener=lambda p, flags: os.open(p, flags, 0o600)) as stream:
        json.dump(data, stream, indent=2)
        stream.write("\n")
    os.chmod(temp, 0o600)
    temp.replace(path)


def read_private(path):
    info = path.stat()
    if info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise RuntimeError(f"Expected a private file owned by you: {path}")
    return json.loads(path.read_text())


def begin():
    user_code = getpass.getpass("Smart Life / Tuya Smart User Code: ").strip()
    if not user_code:
        raise RuntimeError("User Code is empty")
    response = LoginControl().qr_code(CLIENT, SCHEMA, user_code)
    if not response.get("success"):
        raise RuntimeError("Tuya did not issue an authorization QR code for this account")
    token = response["result"]["qrcode"]
    write_private(PENDING, {"user_code": user_code, "token": token, "created": time.time()})
    qrcode.make(f"tuyaSmart--qrLogin?token={token}").save(QR)
    os.chmod(QR, 0o600)
    print(f"Scan {QR} with Smart Life / Tuya Smart and approve the Home Assistant/Tuya authorization.")
    print("Then run this helper with 'finish'. No device power changes are requested.")


def finish():
    pending = read_private(PENDING)
    if time.time() - pending["created"] > 600:
        raise RuntimeError("Pending login is old; generate a fresh QR code with 'begin'")
    success, info = LoginControl().login_result(pending["token"], CLIENT, pending["user_code"])
    if not success:
        raise RuntimeError("Authorization is not complete or has expired; scan/approve or generate a fresh QR code")
    api = CustomerApi(CustomerTokenInfo(info), CLIENT, pending["user_code"],
                      info["endpoint"], SharingTokenListener())
    try:
        result = api.get("/v1.0/m/life/ha/devices/detail", {"devIds": DEVICE_ID})
        devices = result.get("result", []) if result and result.get("success") else []
        matches = [device for device in devices if device.get("id") == DEVICE_ID]
        if len(matches) != 1:
            raise RuntimeError("Authorized account did not return the confirmed drive bay device")
        key = matches[0].get("local_key", "")
        if not isinstance(key, str) or len(key.encode()) != 16:
            raise RuntimeError("Tuya did not return a valid local key for drive bay")
        config = read_private(CONFIG)
        if config.get("device_id") != DEVICE_ID:
            raise RuntimeError("Local configuration no longer matches the confirmed plug")
        config["local_key"] = key
        write_private(CONFIG, config)
        print(f"Saved only drive bay's local key privately to {CONFIG}; no power command sent.")
    finally:
        try:
            UserRepository(api).unload(info["terminal_id"])
        except Exception:
            print("Could not revoke the temporary cloud session; remove its authorization in the app.", file=sys.stderr)
        api.session.close()
        PENDING.unlink(missing_ok=True)
        QR.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("begin", "finish"))
    args = parser.parse_args()
    os.umask(0o077)
    DIRECTORY.mkdir(mode=0o700, exist_ok=True)
    # The SDK can include HTTP bodies in diagnostics. Never log auth material.
    logging.disable(logging.CRITICAL)
    try:
        (begin if args.action == "begin" else finish)()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Authorization could not complete ({type(exc).__name__}); no credentials printed.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
