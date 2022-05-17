#!/bin/bash
echo "download"
wget --no-check-certificate https://download.mikrotik.com/routeros/7.3beta40/chr-7.3beta40.img.zip -O /tmp/chr.img.zip
echo "unzip"
unzip -p /tmp/chr.img.zip > /tmp/chr.img
echo "remove old image file"
rm -rf  chr.qcow2
echo "convert raw to qcow2"
qemu-img convert -f raw -O qcow2 /tmp/chr.img chr.qcow2
echo "remove raw image"
rm -rf /tmp/chr.im*
echo "load nbd kernel module"
modprobe nbd
echo "connect image as /dev/nbd0"
qemu-nbd -c /dev/nbd0 chr.qcow2
echo "clear previous tmp files"
rm -rf /tmp/tmp*
echo "create tmp directories"
mkdir /tmp/tmpmount/
mkdir /tmp/tmpefipart/
echo "mount first partition"
mount /dev/nbd0p1 /tmp/tmpmount/
echo "copy efi/boot files from first partition"
rsync -a /tmp/tmpmount/ /tmp/tmpefipart/
echo "umount first partition"
umount /dev/nbd0p1
echo "format first partion as fat32"
mkfs -t fat /dev/nbd0p1
echo "mount first partition"
mount /dev/nbd0p1 /tmp/tmpmount/
echo "copy efi/boot files to first partition"
rsync -a /tmp/tmpefipart/ /tmp/tmpmount/
echo "umount first partition"
umount /dev/nbd0p1
echo "mount second partition"
mount /dev/nbd0p2 /tmp/tmpmount/
echo
echo "in 5 seconds you can modify initial config of chr"
sleep 5
nano /tmp/tmpmount/rw/autorun.scr
echo "umount second partition"
umount /dev/nbd0p2
echo "clear previous tmp files"
rm -rf /tmp/tmp*
echo "modify partition table"
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
echo "disconnect image from /dev/nbd0"
sudo qemu-nbd -d /dev/nbd0
echo
echo "script finished, created file chr.qcow2"
