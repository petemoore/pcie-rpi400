#!/usr/bin/env bash

set -eu

cd "$(dirname "${0}")"
rm -r dist
wget -q -O raspi-firmware_1.20241126.orig.tar.xz https://github.com/raspberrypi/firmware/releases/download/1.20241126/raspi-firmware_1.20241126.orig.tar.xz
tar xvfz raspi-firmware_1.20241126.orig.tar.xz
mv raspi-firmware-1.20241126/boot dist
rm -r raspi-firmware{-1.20241126,_1.20241126.orig.tar.xz}
aarch64-none-elf-as -g -o pcie-rpi400.o pcie-rpi400.s 
aarch64-none-elf-ld -M -o pcie-rpi400.elf pcie-rpi400.o
aarch64-none-elf-objcopy --set-start=0x0 pcie-rpi400.elf -O binary dist/pcie-rpi400.img
aarch64-none-elf-objdump -b binary -z --adjust-vma=0x0 -maarch64 -D dist/pcie-rpi400.img
rm pcie-rpi400.{o,elf}
cp config.txt dist

echo 'All done!'
