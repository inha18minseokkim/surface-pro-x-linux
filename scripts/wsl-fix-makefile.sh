#!/usr/bin/env bash
set -e
MK=/root/kernel/arch/arm64/boot/dts/qcom/Makefile
sed -i '/^dtb- += sc8180xp-spx-minimal.dtb$/d' "$MK"
grep -q 'sc8180xp-spx-minimal' "$MK" || \
  sed -i '/sc8180xp-microsoft-surface-pro-x.dtb/a dtb-$(CONFIG_ARCH_QCOM) += sc8180xp-spx-minimal.dtb' "$MK"
grep sc8180xp "$MK"
