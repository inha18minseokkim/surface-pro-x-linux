#!/usr/bin/env bash
# Add boot-log auto-collection to the rootfs image (loop mount in WSL):
#  - spx-logdump.service: dump dmesg/journal/device info to the FAT32 boot
#    partition on every boot (works headless/keyboardless)
#  - persistent journal, msm blacklist (belt & suspenders), autologin on tty1
set -euo pipefail

IMG=/root/spx-rootfs.img
MNT=/mnt/spxroot
BOOT_PARTUUID=0dde39ea-8977-4f43-af63-b01482bee319

mkdir -p "$MNT"
mount -o loop "$IMG" "$MNT"
trap 'umount "$MNT" 2>/dev/null || true' EXIT

# 1. log dump service
cat > "$MNT/usr/local/bin/spx-logdump.sh" <<'EOF'
#!/bin/bash
# Dump boot evidence to the FAT32 boot partition.
BOOTDEV=/dev/disk/by-partuuid/0dde39ea-8977-4f43-af63-b01482bee319
mkdir -p /mnt/bootpart
for i in $(seq 1 30); do [ -e "$BOOTDEV" ] && break; sleep 1; done
mount "$BOOTDEV" /mnt/bootpart || exit 1
{
  echo "==== boot $(date -u +%FT%TZ) kernel $(uname -r)"
  echo "==== dmesg"; dmesg
  echo "==== lsblk"; lsblk
  echo "==== lspci"; lspci -nn 2>/dev/null
  echo "==== lsusb"; lsusb 2>/dev/null
  echo "==== ip"; ip a
  echo "==== mods"; lsmod
  echo "==== failed units"; systemctl --failed --no-pager 2>/dev/null
} > /mnt/bootpart/spx-bootlog.txt 2>&1
sync
umount /mnt/bootpart
EOF
chmod +x "$MNT/usr/local/bin/spx-logdump.sh"

cat > "$MNT/etc/systemd/system/spx-logdump.service" <<'EOF'
[Unit]
Description=Dump boot logs to FAT32 boot partition
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/spx-logdump.sh
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/spx-logdump.service \
    "$MNT/etc/systemd/system/multi-user.target.wants/spx-logdump.service"

# 2. persistent journal
mkdir -p "$MNT/var/log/journal"

# 3. blacklist display takeover (also done via cmdline module_blacklist=)
cat > "$MNT/etc/modprobe.d/spx-bringup-blacklist.conf" <<'EOF'
# bring-up: keep efifb console alive; enable one by one later
blacklist msm
EOF

# 4. autologin root on tty1 (no Type Cover in DT mode yet)
mkdir -p "$MNT/etc/systemd/system/getty@tty1.service.d"
cat > "$MNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

umount "$MNT"
trap - EXIT
e2fsck -fp "$IMG" > /dev/null || true
echo "ROOTFS UPDATED"
