#!/bin/bash

error() {
    printf "%s\n" "$*" >&2
    exit 1
}

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

format_efi() {
    local disk
    disk=$1
    sudo mkfs.vfat -n EFI "${disk}-part1"
    sudo mkdir -p "/mnt/boot/efis/${disk##*/}-part1"
    sudo mount -t vfat "${disk}-part1" "/mnt/boot/efis/${disk##*/}-part1"
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR" || exit 1

sudo apt update
export DEBIAN_FRONTEND=noninteractive
sudo -E apt install -yqq dosfstools zfs-dkms zfsutils-linux whois python3 python3-pip
sudo pip install jinja2-cli

sudo -i nix-channel --update
sudo -i nix-env -iA nixpkgs.nix nixpkgs.nixos-install-tools

# Load zfs kernel module
sudo /sbin/modprobe zfs

nix_disk="$(find_disk '/dev/sdb')"
live_disk="$(find_disk '/dev/sda')"

# Wipe disk
sudo wipefs -a "$nix_disk"

# Clear zfs labels on both disks
sudo zpool labelclear -f "$nix_disk"
sudo zpool labelclear -f "$live_disk"

# Remove swap
sudo swapoff -a
sudo sed -i '/.*swap.*/d' /etc/fstab
sudo sgdisk --delete=5 "$live_disk" && sudo partx -u /dev/sda5

# EFI/Boot partitions
sudo sgdisk --new=1:1M:+1G --typecode=1:EF00 "$nix_disk"

# ZFS Root partition
sudo sgdisk --new=2:0:0 --typecode=2:BF00 "$nix_disk"

sleep 5

set -e
# Create root pool
sudo zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -R /mnt \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/ \
    rpool \
    -f \
    "$nix_disk-part2"

# Create root system container
sudo zfs create \
    -o canmount=off \
    -o mountpoint=none \
    rpool/nixos

# Create system datasets
sudo zfs create -o canmount=on -o mountpoint=/ rpool/nixos/root
sudo zfs create -o canmount=on -o mountpoint=/home rpool/nixos/home
sudo zfs create -o canmount=off -o mountpoint=/var rpool/nixos/var
sudo zfs create -o canmount=on rpool/nixos/var/lib
sudo zfs create -o canmount=on rpool/nixos/var/log

# Create and mount ESP partitions
sudo mkfs.vfat "$nix_disk-part1"
sudo mkdir -p /mnt/boot
sudo mount "$nix_disk-part1" /mnt/boot

sudo mkdir -p /mnt/etc/zfs/
sudo rm -f /mnt/etc/zfs/zpool.cache
sudo touch /mnt/etc/zfs/zpool.cache
sudo chmod a-w /mnt/etc/zfs/zpool.cache
sudo chattr +i /mnt/etc/zfs/zpool.cache
sudo -i nixos-generate-config --root /mnt

password=$(openssl rand -base64 12)
NIX_HASHED_PASSWORD=$(mkpasswd -m SHA-512 "$password")
NIX_GRUB_DEVICES="$nix_disk"
NIX_HOSTID="$(head -c 8 /etc/machine-id)"
NIX_HOSTNAME=$(hostname)
NIX_DOMAIN=$(hostname -d)

export \
    NIX_HASHED_PASSWORD \
    NIX_GRUB_DEVICES \
    NIX_HOSTID \
    NIX_HOSTNAME \
    NIX_DOMAIN

sudo -E python3 gen_conf.py --path /mnt/etc/nixos
sudo -i sed -i 's|fsType = "zfs";|fsType = "zfs"; options = [ "zfsutil" "X-mount.mkdir" ];|g' /mnt/etc/nixos/hardware-configuration.nix
# sudo -i nixos-install -v --show-trace --no-root-passwd --root /mnt
# bootmgr_disk=$(echo "$nix_disk" | awk -F_ '{print $NF}')
exit 0
