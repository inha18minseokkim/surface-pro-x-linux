#!/usr/bin/env bash
set -euo pipefail
KDIR=/root/kernel
REPO=/mnt/c/Users/Surface/Desktop/ubuntu-surface/repo
OUT=/mnt/c/Users/Surface/Desktop/ubuntu-surface/build-output

cd "$KDIR"
cp "$REPO"/dts/sc8180xp-spx-control.dts arch/arm64/boot/dts/qcom/
MK=arch/arm64/boot/dts/qcom/Makefile
grep -q spx-control "$MK" || \
  sed -i '/sc8180xp-spx-minimal.dtb/a dtb-$(CONFIG_ARCH_QCOM) += sc8180xp-spx-control.dtb' "$MK"
make -j8 qcom/sc8180xp-spx-control.dtb 2>&1 | tail -2
cp arch/arm64/boot/dts/qcom/sc8180xp-spx-control.dtb "$OUT/"
ls -la "$OUT"/sc8180xp-spx-control.dtb
