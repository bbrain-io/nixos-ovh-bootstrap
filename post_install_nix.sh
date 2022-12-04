#!/bin/bash

find_disk() {
    local real_path
    real_path=$1

    disks=()
    for disk in /dev/disk/by-id/ata-*; do
        if echo "$disk" | grep -P "\-part[0-9]*$" >/dev/null; then
            continue
        fi
        if [ "$(readlink -f "$disk")" != "$real_path" ]; then
            continue
        fi
        disks+=("$disk")
    done

    [ "${#disks[@]}" -ne 1 ] && error "Couldn't find matching disk"

    echo "${disks[0]}"
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR" || exit 1

old_disk="$(find_disk '/dev/sdb')"
nix_disk="$(find_disk '/dev/sda')"

sudo wipefs -a "$old_disk"

# EFI/Boot partitions
sudo sgdisk --new=1:1M:+1G --typecode=1:EF00 "$old_disk"

# ZFS Root partition
sudo sgdisk --new=2:0:0 --typecode=2:BF00 "$nix_disk"

# Create and mount ESP partition
sudo mkfs.vfat "$old_disk-part1"
sudo mount "$old_disk-part1" /boot-fallback

NIX_GRUB_DEVICES="$old_disk $nix_disk"
export NIX_GRUB_DEVICES

sudo -E python3 gen_conf.py --path /etc/nixos --template zfs.nix.j2
sudo -E python3 gen_conf.py --path /etc/nixos --template configuration.nix
