#!/usr/bin/env bash
# Prepare the WSL kernel tree: apply patches, inject DTS, merge config.
# Run inside WSL: bash scripts/wsl-prepare-tree.sh [kernel-tree]
set -euo pipefail

KDIR="${1:-$HOME/kernel}"
REPO="/mnt/c/Users/Surface/Desktop/ubuntu-surface/repo"

cd "$KDIR"

# 1. Patches
if git apply --check "$REPO"/patches/0100-*.patch 2>/dev/null; then
    git apply "$REPO"/patches/0100-*.patch
    echo "== patch 0100 applied"
else
    echo "== patch 0100 already applied or failed check"
    git apply --check "$REPO"/patches/0100-*.patch || true
fi

# 2. DTS
cp "$REPO"/dts/sc8180xp.dtsi "$REPO"/dts/sc8180xp-microsoft-surface-pro-x.dts \
   arch/arm64/boot/dts/qcom/
MK=arch/arm64/boot/dts/qcom/Makefile
grep -q sc8180xp-microsoft "$MK" || \
    sed -i '/sc8180x-lenovo-flex-5g.dtb/a dtb-$(CONFIG_ARCH_QCOM) += sc8180xp-microsoft-surface-pro-x.dtb' "$MK"
echo "== DTS injected:"
grep sc8180 "$MK"

# 3. Config: defconfig + Surface fragment
make defconfig > /dev/null
# config fragment may have CRLF from Windows checkout
sed 's/\r$//' "$REPO"/configs/surface-pro-x.config > /tmp/spx.config
./scripts/kconfig/merge_config.sh -m .config /tmp/spx.config > /tmp/merge.log
grep -E "not in final|Actual value" /tmp/merge.log || echo "== all fragment options merged"
make olddefconfig > /dev/null
echo "== config ready; spot checks:"
grep -E "^CONFIG_(ARCH_QCOM|PCIE_QCOM|ATH10K_SNOC|QCOM_Q6V5_PAS|QCOM_IPA|DRM_MSM|SC_GCC_8180X)=" .config
