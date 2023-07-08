#!/bin/sh
echo "install packages"
apk add qemu-img curl rsync gptfdisk dosfstools efibootmgr lsblk
modprobe nbd max_part=8
echo "download"
wget --no-check-certificate https://download.mikrotik.com/routeros/7.11beta4/chr-7.11beta4.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.8/chr-7.8.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.5/chr-7.5.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.3beta40/chr-7.3beta40.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.3beta40/chr-7.3beta40.vhdx -O /run/chr.img
echo "unzip"
unzip -p /run/chr.img.zip > /run/chr.img
echo "convert raw to qcow2"
qemu-img convert -f raw -O qcow2 /run/chr.img /root/chr.qcow2
#qemu-img convert -f vhdx -O qcow2 /run/chr.img chr.qcow2
echo "connect image as /dev/nbd0"
qemu-nbd -c /dev/nbd0 /root/chr.qcow2
echo "create tmp directories"
mkdir /run/tmpmount/
mkdir /run/tmpefipart/
echo "mount first partition"
mount -t ext2 /dev/nbd0p1 /run/tmpmount/
echo "copy efi/boot files from first partition"
rsync -a /run/tmpmount/ /run/tmpefipart/
echo "umount first partition"
umount /dev/nbd0p1
echo "format first partion as fat32"
mkfs.fat /dev/nbd0p1
echo "mount first partition"
mount -t vfat /dev/nbd0p1 /run/tmpmount/
echo "copy efi/boot files to first partition"
rsync -a /run/tmpefipart/ /run/tmpmount/
echo "umount first partition"
umount /dev/nbd0p1
echo "mount second partition"
mount -t ext3 /dev/nbd0p2 /run/tmpmount/
#echo
#echo "in 5 seconds you can modify initial config of chr"
#sleep 5
#cat initial.rsc > /run/tmpmount/rw/autorun.scr
#cat import-p1.rsc > /run/tmpmount/rw/autorun.scr
echo "curl from lxd user-data"
curl -s --unix-socket /dev/lxd/sock lxd/1.0/config/cloud-init.user-data >> /run/tmpmount/rw/autorun.scr
#nano /run/tmpmount/rw/autorun.scr
echo "umount second partition"
umount /dev/nbd0p2
echo "modify partition table"
#exit 0
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
partprobe /dev/dbd0
echo "disconnect image from /dev/nbd0"
qemu-nbd -d /dev/nbd0
echo "script finished, created file chr.qcow2"
#qemu-img convert -f qcow2 -O vhdx chr.qcow2 chr.vhdx
echo "convert to img"
qemu-img convert -f qcow2 -O raw /root/chr.qcow2 /root/chr.img
#exit 0
#echo "wait 180 seconds to avoid race condition in cloud-init"
#sleep 180
sync
echo "umount modloop"
umount /.modloop
echo "umount sda1"
umount /media/sda1
sync
echo "erase gpt on sda"
(
echo x # expert
echo z # zap
echo y # confirm
echo y # clear mbr
) | gdisk /dev/sda
sync
partprobe /dev/sda
echo "overwrite sda"
dd if=/root/chr.img of=/dev/sda bs=4M
sync
partprobe /dev/sda
(
echo x # expert
echo e # relocate backup table
echo w # write changes
echo y # confirm
) | gdisk /dev/sda
sync
partprobe /dev/sda
efibootmgr -c -d /dev/sda -l \\EFI\\BOOT\\BOOTX64.EFI -L "RouterOS"
#reboot
