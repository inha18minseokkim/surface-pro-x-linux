#!/usr/bin/env bash
# Collect kernel build artifacts to the Windows-side build-output directory.
set -euo pipefail

KDIR="${1:-$HOME/kernel}"
OUT=/mnt/c/Users/Surface/Desktop/ubuntu-surface/build-output

cd "$KDIR"
KREL=$(make -s kernelrelease)
mkdir -p "$OUT"

# Clean up any directories created by earlier quoting accidents
rmdir '$OUT' ';' 2>/dev/null || true

cp arch/arm64/boot/Image.gz "$OUT/"
cp arch/arm64/boot/dts/qcom/sc8180xp-microsoft-surface-pro-x.dtb "$OUT/"
cp .config "$OUT/kernel-config-$KREL"

if [ ! -d "/root/modstage/lib/modules/$KREL/kernel" ]; then
    make -s INSTALL_MOD_PATH=/root/modstage modules_install
fi
tar -C /root/modstage -czf "$OUT/modules-$KREL.tar.gz" lib

echo "== artifacts:"
ls -la "$OUT"
echo "== module count:"
find /root/modstage/lib/modules -name '*.ko*' | wc -l
