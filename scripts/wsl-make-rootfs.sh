#!/usr/bin/env bash
# Build an Ubuntu ARM64 rootfs as a raw ext4 image inside WSL2 (native arm64
# chroot, no emulation). The image is later raw-written to the internal NVMe
# partition from elevated Windows.
#
# Output: /root/spx-rootfs.img (8 GiB sparse) + UUID in
#         /mnt/c/Users/Surface/Desktop/ubuntu-surface/build-output/rootfs-uuid.txt
set -euo pipefail

OUT=/mnt/c/Users/Surface/Desktop/ubuntu-surface/build-output
STAGE_FW=/mnt/c/Users/Surface/Desktop/ubuntu-surface/firmware-staging
IMG=/root/spx-rootfs.img
MNT=/mnt/spxroot
SIZE_GIB=8
UBUNTU_BASE_URLS=(
  "https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz"
  "https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz"
  "https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.2-base-arm64.tar.gz"
)

echo "== [1/7] base tarball"
cd /root
if [ ! -f ubuntu-base.tar.gz ]; then
    for u in "${UBUNTU_BASE_URLS[@]}"; do
        echo "trying $u"
        if wget -q --tries=2 -O ubuntu-base.tar.gz "$u"; then break; fi
    done
fi
[ -s ubuntu-base.tar.gz ] || { echo "FATAL: could not download ubuntu-base"; exit 1; }
ls -la ubuntu-base.tar.gz

echo "== [2/7] image + ext4"
rm -f "$IMG"
truncate -s ${SIZE_GIB}G "$IMG"
FSUUID=$(cat /proc/sys/kernel/random/uuid)
mkfs.ext4 -q -U "$FSUUID" -L spx-root "$IMG"
mkdir -p "$OUT"
echo "$FSUUID" > "$OUT/rootfs-uuid.txt"
echo "rootfs UUID: $FSUUID"

mkdir -p "$MNT"
mount -o loop "$IMG" "$MNT"
trap 'umount -R "$MNT" 2>/dev/null || true' EXIT

echo "== [3/7] extract base"
tar -xpzf ubuntu-base.tar.gz -C "$MNT"

echo "== [4/7] chroot prep"
mount -t proc proc "$MNT/proc"
mount -t sysfs sys "$MNT/sys"
mount --bind /dev "$MNT/dev"
mount --bind /dev/pts "$MNT/dev/pts"
cp /etc/resolv.conf "$MNT/etc/resolv.conf"

echo "== [5/7] packages (native arm64 chroot)"
chroot "$MNT" /bin/bash -e <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q --no-install-recommends \
    systemd systemd-sysv udev dbus kmod util-linux login passwd sudo \
    iproute2 iputils-ping network-manager wpasupplicant \
    openssh-server pciutils usbutils nano less ca-certificates \
    modemmanager libqmi-utils libmbim-utils e2fsprogs
apt-get clean

echo spx > /etc/hostname
printf '127.0.0.1 localhost\n127.0.1.1 spx\n' > /etc/hosts

# user: surface / surface
useradd -m -s /bin/bash -G sudo surface
echo 'surface:surface' | chpasswd
echo 'root:surface' | chpasswd

systemctl enable NetworkManager ssh
# serial console for debugging (qcom geni uart)
systemctl enable serial-getty@ttyMSM0.service || true
CHROOT

echo "== [6/7] kernel modules + firmware"
KREL=$(ls /root/modstage/lib/modules | head -1)
cp -a /root/modstage/lib/modules "$MNT/lib/"
mkdir -p "$MNT/lib/firmware"
cp -a "$STAGE_FW"/. "$MNT/lib/firmware/"
echo "modules: $KREL ; firmware:"
ls "$MNT/lib/firmware"

echo "== [7/7] fstab + cleanup"
cat > "$MNT/etc/fstab" <<EOF
UUID=$FSUUID / ext4 defaults,noatime 0 1
EOF
rm -f "$MNT/etc/resolv.conf"
ln -sf /run/systemd/resolve/stub-resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true

umount -R "$MNT"
trap - EXIT
e2fsck -fp "$IMG" > /dev/null || true
echo "== DONE: $IMG ($(du -h --apparent-size "$IMG" | cut -f1) apparent, $(du -h "$IMG" | cut -f1) actual)"
echo "UUID=$FSUUID"
