#!/bin/bash

# slette-disk.sh - Wiper disker totalt inkl ZFS metadata
# Bruk: bash slette-disk.sh sda sdb sdc

if [ "$#" -eq 0 ]; then
    echo "Bruk: bash slette-disk.sh sda sdb sdc ..."
    exit 1
fi

for disk in "$@"; do
    DEV="/dev/$disk"

    if [ ! -b "$DEV" ]; then
        echo "FEIL: $DEV finnes ikke, hopper over..."
        continue
    fi

    echo "================================================"
    echo "  Sletter $DEV ..."
    echo "================================================"

    echo "  [1/4] Dreper ZFS pools på $DEV..."
    zpool labelclear -f "$DEV" 2>/dev/null

    echo "  [2/4] Wipefs alle signaturer på $DEV..."
    wipefs -a "$DEV"

    echo "  [3/4] Nuller starten av $DEV..."
    dd if=/dev/zero of="$DEV" bs=1M count=100 status=progress

    echo "  [4/4] Nuller slutten av $DEV..."
    END=$(( $(blockdev --getsz "$DEV") / 2048 - 100 ))
    dd if=/dev/zero of="$DEV" bs=1M count=100 seek=$END status=progress

    echo "  ✓ $DEV er helt ren!"
    echo ""
done

echo "Alle disker ferdig slettet! Klar for Proxmox install."
