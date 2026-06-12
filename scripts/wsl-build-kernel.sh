#!/usr/bin/env bash
# Native ARM64 kernel build inside WSL2 Ubuntu on the Surface Pro X itself.
# Run: bash scripts/wsl-build-kernel.sh [kernel-tree]
set -uo pipefail

KDIR="${1:-$HOME/kernel}"
LOG=/root/build.log

cd "$KDIR"
make -j"$(nproc)" Image.gz dtbs modules > "$LOG" 2>&1
ec=$?
echo "BUILD_EXIT=$ec"
if [ "$ec" -ne 0 ]; then
    grep -iE "error[: ]" "$LOG" | head -20
fi
tail -5 "$LOG"
ls -la arch/arm64/boot/Image.gz arch/arm64/boot/dts/qcom/sc8180xp-microsoft-surface-pro-x.dtb 2>/dev/null
exit "$ec"
