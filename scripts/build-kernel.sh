#!/usr/bin/env bash
# Cross-build ARM64 kernel + DTBs with the Surface Pro X config fragment.
# Usage: ./scripts/build-kernel.sh [path-to-kernel-tree]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
KDIR="${1:-$REPO/work/kernel}"
JOBS="$(nproc)"

[ -d "$KDIR" ] || { echo "kernel tree not found: $KDIR (run fetch-sources.sh)"; exit 1; }

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

cd "$KDIR"

# Base config + Surface Pro X fragment
make defconfig
./scripts/kconfig/merge_config.sh -m .config "$REPO/configs/surface-pro-x.config"
make olddefconfig

# Copy our DTS into the tree if present (issue #3 deliverable)
if ls "$REPO"/dts/*.dts >/dev/null 2>&1; then
    cp "$REPO"/dts/*.dts* arch/arm64/boot/dts/qcom/
    # Note: new .dts files must also be added to arch/arm64/boot/dts/qcom/Makefile
    grep -q sc8180xp-microsoft-surface-pro-x arch/arm64/boot/dts/qcom/Makefile || \
        echo 'dtb-$(CONFIG_ARCH_QCOM) += sc8180xp-microsoft-surface-pro-x.dtb' \
            >> arch/arm64/boot/dts/qcom/Makefile
fi

make -j"$JOBS" Image.gz dtbs modules

echo
echo "Build done:"
echo "  Kernel: $KDIR/arch/arm64/boot/Image.gz"
echo "  DTBs:   $KDIR/arch/arm64/boot/dts/qcom/"
