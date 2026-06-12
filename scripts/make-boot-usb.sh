#!/usr/bin/env bash
# Create a bootable USB for Surface Pro X bring-up (ARM64 GRUB + kernel + rootfs).
# Usage: sudo ./scripts/make-boot-usb.sh /dev/sdX [Image.gz] [rootfs.tar.gz]
# WARNING: wipes the target disk.
set -euo pipefail

DISK="${1:?usage: make-boot-usb.sh /dev/sdX [Image.gz] [rootfs.tar.gz]}"
KERNEL="${2:-}"
ROOTFS_TAR="${3:-}"
GRUB_URL="https://github.com/linux-surface/grub-image-aarch64/releases/latest/download/grubaa64.efi"

[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
lsblk "$DISK"
read -rp "ERASE $DISK entirely? [yes/NO] " ans
[ "$ans" = yes ] || exit 1

# Partition: 512M ESP + rest ext4
wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB set 1 esp on \
    mkpart root ext4 513MiB 100%
sleep 1
P1=$(lsblk -nrpo NAME "$DISK" | sed -n 2p)
P2=$(lsblk -nrpo NAME "$DISK" | sed -n 3p)

mkfs.vfat -F32 -n ESP "$P1"
mkfs.ext4 -F -L spx-root "$P2"

ESP=$(mktemp -d); ROOT=$(mktemp -d)
mount "$P1" "$ESP"; mount "$P2" "$ROOT"
trap 'umount "$ESP" "$ROOT" 2>/dev/null || true' EXIT

# GRUB (known-good ARM64 image from linux-surface)
mkdir -p "$ESP/EFI/BOOT"
wget -O "$ESP/EFI/BOOT/BOOTAA64.EFI" "$GRUB_URL"

# Kernel + DTB
if [ -n "$KERNEL" ]; then
    cp "$KERNEL" "$ESP/Image.gz"
    DTB="$(dirname "$KERNEL")/dts/qcom/sc8180xp-microsoft-surface-pro-x.dtb"
    [ -f "$DTB" ] && cp "$DTB" "$ESP/"
fi

# Rootfs
if [ -n "$ROOTFS_TAR" ]; then
    tar -xpf "$ROOTFS_TAR" -C "$ROOT"
fi

ESP_UUID=$(blkid -s UUID -o value "$P1")
ROOT_UUID=$(blkid -s UUID -o value "$P2")

cat > "$ESP/EFI/BOOT/grub.cfg" <<EOF
set timeout=3
menuentry "Ubuntu ARM64 (ACPI bring-up)" {
    search --no-floppy --fs-uuid --set=root $ESP_UUID
    linux /Image.gz root=UUID=$ROOT_UUID rw \\
        console=tty0 console=ttyMSM0,115200 \\
        clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime
}
menuentry "Ubuntu ARM64 (Device Tree)" {
    search --no-floppy --fs-uuid --set=root $ESP_UUID
    devicetree /sc8180xp-microsoft-surface-pro-x.dtb
    linux /Image.gz root=UUID=$ROOT_UUID rw \\
        console=tty0 console=ttyMSM0,115200 \\
        clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime
}
EOF

sync
echo "Done. Boot the Surface Pro X with volume-down held to boot from USB."
