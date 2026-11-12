#!/usr/bin/env python3
"""Send riley-server's Wake-on-LAN packet from another machine on its LAN."""

import argparse
import socket
import time

MAC = "fc:34:97:bc:37:4d"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--broadcast", default="192.168.1.255")
    parser.add_argument("--source", help="Optional sender IPv4 address to select a LAN interface")
    args = parser.parse_args()
    packet = b"\xff" * 6 + bytes.fromhex(MAC.replace(":", "")) * 16
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        if args.source:
            sock.bind((args.source, 0))
        for attempt in range(3):
            sock.sendto(packet, (args.broadcast, 9))
            if attempt < 2:
                time.sleep(1)
    print(f"Sent three wake packets for {MAC} to {args.broadcast}:9; awaiting server startup.")


if __name__ == "__main__":
    main()
