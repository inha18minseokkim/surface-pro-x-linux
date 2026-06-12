#!/usr/bin/env bash
# Round 5: watchdog + USB2-only minimal DTS, rebuild, stage artifacts.
set -euo pipefail

KDIR=/root/kernel
REPO=/mnt/c/Users/Surface/Desktop/ubuntu-surface/repo
OUT=/mnt/c/Users/Surface/Desktop/ubuntu-surface/build-output

cd "$KDIR"
cp "$REPO"/dts/sc8180xp.dtsi "$REPO"/dts/sc8180xp-spx-minimal.dts \
   "$REPO"/dts/sc8180xp-microsoft-surface-pro-x.dts arch/arm64/boot/dts/qcom/

sed 's/\r$//' "$REPO"/configs/surface-pro-x.config > /tmp/spx.config
./scripts/kconfig/merge_config.sh -m .config /tmp/spx.config > /dev/null
make olddefconfig > /dev/null
grep -E "CONFIG_QCOM_WDT=" .config

make -j"$(nproc)" Image.gz dtbs > /root/round5.log 2>&1
ec=$?
echo "BUILD_EXIT=$ec"
[ $ec -ne 0 ] && { grep -iE "error[: ]" /root/round5.log | head; exit $ec; }

cp arch/arm64/boot/Image.gz "$OUT/"
cp arch/arm64/boot/dts/qcom/sc8180xp-spx-minimal.dtb "$OUT/"
cp arch/arm64/boot/dts/qcom/sc8180xp-microsoft-surface-pro-x.dtb "$OUT/"
ls -la "$OUT"/Image.gz "$OUT"/*.dtb
echo DONE
