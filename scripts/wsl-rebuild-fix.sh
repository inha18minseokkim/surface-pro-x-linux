#!/usr/bin/env bash
# Incremental rebuild after config fragment changes; refresh artifacts.
set -euo pipefail

KDIR="${1:-$HOME/kernel}"
REPO=/mnt/c/Users/Surface/Desktop/ubuntu-surface/repo
OUT=/mnt/c/Users/Surface/Desktop/ubuntu-surface/build-output

cd "$KDIR"
sed 's/\r$//' "$REPO"/configs/surface-pro-x.config > /tmp/spx.config
./scripts/kconfig/merge_config.sh -m .config /tmp/spx.config > /tmp/merge.log
make olddefconfig > /dev/null
grep -E "CONFIG_(QCOM_GENI_SE|I2C_QCOM_GENI|SPI_QCOM_GENI|SERIAL_QCOM_GENI)=" .config

make -j"$(nproc)" Image.gz modules > /root/rebuild.log 2>&1
ec=$?
echo "REBUILD_EXIT=$ec"
[ $ec -ne 0 ] && { grep -iE "error[: ]" /root/rebuild.log | head; exit $ec; }

make -s INSTALL_MOD_PATH=/root/modstage modules_install
cp arch/arm64/boot/Image.gz "$OUT/"
cp .config "$OUT/kernel-config-$(make -s kernelrelease)"
tar -C /root/modstage -czf "$OUT/modules-$(make -s kernelrelease).tar.gz" lib
ls -la "$OUT/Image.gz"
echo DONE
