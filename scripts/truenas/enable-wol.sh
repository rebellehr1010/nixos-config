#!/bin/sh
# Run as a TrueNAS POSTINIT task; keep this file on app_pool across upgrades.
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LC_ALL=C
export PATH LC_ALL

target_mac=fc:34:97:bc:37:4d
interface=
for device in /sys/class/net/*; do
    [ -d "$device/device" ] || continue
    [ "$(cat "$device/address")" = "$target_mac" ] || continue
    if [ -n "$interface" ]; then
        echo "More than one physical interface matches $target_mac" >&2
        exit 1
    fi
    interface=${device##*/}
done
if [ -z "$interface" ]; then
    echo "No physical interface matches $target_mac" >&2
    exit 1
fi

ethtool -s "$interface" wol g
ethtool "$interface" | grep -q '^[[:space:]]*Wake-on: g$'
logger -t truenas-wol "Magic-packet wake enabled on $interface ($target_mac)"
echo "Magic-packet wake enabled on $interface ($target_mac)"
