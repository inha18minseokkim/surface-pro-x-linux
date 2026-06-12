#!/usr/bin/env bash
# Clone kernel source and reference repos into ./work (gitignored).
set -euo pipefail

WORK="$(dirname "$0")/../work"
mkdir -p "$WORK"
cd "$WORK"

clone() { # clone <url> <dir> [branch]
    local url="$1" dir="$2" branch="${3:-}"
    if [ -d "$dir/.git" ]; then
        echo ">> $dir exists, skipping"
        return
    fi
    if [ -n "$branch" ]; then
        git clone --depth 1 -b "$branch" "$url" "$dir"
    else
        git clone --depth 1 "$url" "$dir"
    fi
}

# Primary kernel base: linux-surface kernel (check for latest spx/ branch manually)
clone https://github.com/linux-surface/kernel.git kernel

# Reference: denysvitali's SPX patches (old, 5.16, but SPX-specific)
clone https://github.com/denysvitali/surface-pro-x-linux.git ref-denysvitali spx-5.16 || \
    clone https://github.com/denysvitali/surface-pro-x-linux.git ref-denysvitali

# Reference: jhovold's Qualcomm laptop mainline work (sc8280xp patterns)
clone https://github.com/jhovold/linux.git ref-jhovold

# Firmware blobs for aarch64 Surface devices
clone https://github.com/linux-surface/aarch64-firmware.git aarch64-firmware

# aarch64-laptops: ACPI dumps for similar sc8180x machines
clone https://github.com/aarch64-laptops/build.git ref-aarch64-laptops

echo
echo "Sources fetched into $WORK"
echo "Next: ./scripts/build-kernel.sh"
