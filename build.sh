#!/usr/bin/env bash

set -eu
set -o pipefail
export SHELLOPTS

: ${AARCH64_TOOLCHAIN_PREFIX:=aarch64-none-elf-}

cd "$(dirname "${0}")"
rm -r dist
wget -q -O raspi-firmware_1.20241126.orig.tar.xz https://github.com/raspberrypi/firmware/releases/download/1.20241126/raspi-firmware_1.20241126.orig.tar.xz
tar xvfz raspi-firmware_1.20241126.orig.tar.xz
mv raspi-firmware-1.20241126/boot dist
rm -r raspi-firmware{-1.20241126,_1.20241126.orig.tar.xz}

"${AARCH64_TOOLCHAIN_PREFIX}as" -o pcie-rpi400.o pcie-rpi400.s
"${AARCH64_TOOLCHAIN_PREFIX}ld" --no-warn-rwx-segments -N -Ttext=0x0 -o pcie-rpi400.elf pcie-rpi400.o
"${AARCH64_TOOLCHAIN_PREFIX}objcopy" --set-start=0x0 pcie-rpi400.elf -O binary dist/pcie-rpi400.img
"${AARCH64_TOOLCHAIN_PREFIX}objdump" -d pcie-rpi400.elf

cp config.txt dist

echo 'All done!'
