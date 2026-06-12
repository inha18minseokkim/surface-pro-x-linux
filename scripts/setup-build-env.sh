#!/usr/bin/env bash
# Install cross-compile toolchain and kernel build deps (Ubuntu/Debian x86_64 host).
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
    gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    build-essential libssl-dev libelf-dev bc flex bison \
    libncurses-dev kmod cpio rsync \
    python3 git wget \
    device-tree-compiler \
    acpica-tools  # iasl: ACPI table decompile for DT reverse-engineering

echo
echo "Toolchain ready. Use:"
echo "  export ARCH=arm64"
echo "  export CROSS_COMPILE=aarch64-linux-gnu-"
