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

sudo sfdisk --delete "$old_disk"
sudo wipefs -a "$old_disk"
sudo zpool labelclear -f "$old_disk"

# EFI/Boot partitions
sudo sgdisk --new=1:1M:+1G --typecode=1:EF00 "$old_disk"

# ZFS Root partition
sudo sgdisk --new=2:0:0 --typecode=2:BF00 "$old_disk"

# Create and mount ESP partition
sudo mkfs.vfat "$old_disk-part1"
sudo mkdir -p /boot-fallback
sleep 5
sudo mount "$old_disk-part1" /boot-fallback

NIX_GRUB_DEVICES="$nix_disk $old_disk"
export NIX_GRUB_DEVICES

sudo -i nix-channel --add https://nixos.org/channels/nixos-22.11 nixos
sudo -i nix-channel --update

sudo -E python3 gen_conf.py --path /etc/nixos --template zfs.nix.j2
sudo -E python3 gen_conf.py --path /etc/nixos --template configuration.nix

sudo -i nixos-generate-config
sudo -i sed -i 's|fsType = "zfs";|fsType = "zfs"; options = [ "zfsutil" "X-mount.mkdir" ];|g' /etc/nixos/hardware-configuration.nix

sudo zpool attach rpool "$nix_disk" "$old_disk"
sudo -i nixos-rebuild --show-trace --install-bootloader switch
