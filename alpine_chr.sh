#!/bin/sh
apk add qemu-img curl rsync gptfdisk dosfstools
wget --no-check-certificate https://download.mikrotik.com/routeros/7.11beta4/chr-7.11beta4.img.zip -O /run/chr.img.zip
unzip -p /run/chr.img.zip > /run/chr.img
qemu-img convert -f raw -O qcow2 /run/chr.img chr.qcow2
modprobe nbd max_part=8
qemu-nbd -c /dev/nbd0 chr.qcow2
mkdir /run/runmount/
mkdir /run/runefipart/
mount /dev/nbd0p1 /run/runmount/
rsync -a /run/runmount/ /run/runefipart/
umount /dev/nbd0p1
mkfs.fat /dev/nbd0p1
mount -t vfat /dev/nbd0p1 /run/runmount/
rsync -a /run/runefipart/ /run/runmount/
umount /dev/nbd0p1
mount /dev/nbd0p2 /run/runmount/
curl -s --unix-socket /dev/lxd/sock lxd/1.0/config/cloud-init.vendor-data > /run/runmount/rw/autorun.scr
curl -s --unix-socket /dev/lxd/sock lxd/1.0/config/cloud-init.user-data >> /run/runmount/rw/autorun.scr
umount /dev/nbd0p2
(
echo 2 # use GPT
echo t # change partition code
echo 1 # select first partition
echo 8300 # change code to Linux filesystem 8300
echo r # Recovery/transformation
echo h # Hybrid MBR
echo 1 2 # partitions added to the hybrid MBR
echo n # Place EFI GPT (0xEE) partition first in MBR (good for GRUB)? (Y/N)
echo   # Enter an MBR hex code (default 83)
echo y # Set the bootable flag? (Y/N)
echo   # Enter an MBR hex code (default 83)
echo n # Set the bootable flag? (Y/N)
echo n # Unused partition space(s) found. Use one to protect more partitions? (Y/N)
echo w # write changes to disk
echo y # confirm
) | gdisk /dev/nbd0
qemu-nbd -d /dev/nbd0
qemu-img convert -f qcow2 -O raw chr.qcow2 chr.img
sync
dd if=chr.img of=/dev/sda bs=4M
sync
reboot

