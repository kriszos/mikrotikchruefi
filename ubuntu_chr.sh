#!/bin/sh

#echo "install packages"
#apt update
#apt install -y qemu-utils curl rsync gdisk wget unzip
echo "download"
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.11beta4/chr-7.11beta4.img.zip -O /run/chr.img.zip
wget --no-check-certificate https://download.mikrotik.com/routeros/7.8/chr-7.8.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.5/chr-7.5.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.3beta40/chr-7.3beta40.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.3beta40/chr-7.3beta40.vhdx -O /run/chr.img
echo "unzip"
unzip -p /run/chr.img.zip > /run/chr.img
echo "remove old image file"
rm -rf  chr.qcow2
echo "convert raw to qcow2"
qemu-img convert -f raw -O qcow2 /run/chr.img chr.qcow2
#qemu-img convert -f vhdx -O qcow2 /run/chr.img chr.qcow2
echo "remove raw image"
rm -rf /run/chr.im*
echo "load nbd kernel module"
modprobe nbd max_part=8
echo "connect image as /dev/nbd0"
qemu-nbd -c /dev/nbd0 chr.qcow2
echo "clear previous tmp files"
rm -rf /run/tmp*
echo "create tmp directories"
mkdir /run/tmpmount/
mkdir /run/tmpefipart/
echo "mount first partition"
mount /dev/nbd0p1 /run/tmpmount/
echo "copy efi/boot files from first partition"
rsync -a /run/tmpmount/ /run/tmpefipart/
echo "umount first partition"
umount /dev/nbd0p1
echo "format first partion as fat32"
       mkfs -t fat /dev/nbd0p1
#        mkfs.fat /dev/nbd0p1
echo "mount first partition"
       mount /dev/nbd0p1 /run/tmpmount/
#        mount -t vfat /dev/nbd0p1 /run/tmpmount/
echo "copy efi/boot files to first partition"
rsync -a /run/tmpefipart/ /run/tmpmount/
echo "umount first partition"
umount /dev/nbd0p1
echo "mount second partition"
mount /dev/nbd0p2 /run/tmpmount/
#echo
#echo "in 5 seconds you can modify initial config of chr"
#sleep 5
#cat initial.rsc > /run/tmpmount/rw/autorun.scr
#cat import-p1.rsc > /run/tmpmount/rw/autorun.scr
#       curl -s --unix-socket /dev/lxd/sock lxd/1.0/config/cloud-init.vendor-data > /run/tmpmount/rw/autorun.scr
curl -s --unix-socket /dev/lxd/sock lxd/1.0/config/cloud-init.user-data >> /run/tmpmount/rw/autorun.scr
echo "disable lxd-agent"
systemctl stop lxd-agent
systemctl disable lxd-agent
#nano /run/tmpmount/rw/autorun.scr
echo "umount second partition"
umount /dev/nbd0p2
echo "clear previous tmp files"
rm -rf /run/tmp*
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
echo "disconnect image from /dev/nbd0"
qemu-nbd -d /dev/nbd0
echo
echo "script finished, created file chr.qcow2"
#qemu-img convert -f qcow2 -O vhdx chr.qcow2 chr.vhdx
qemu-img convert -f qcow2 -O raw chr.qcow2 chr.img
#exit 0
#echo "wait 180 seconds to avoid race condition in cloud-init"
sleep 5
sync
dd if=chr.img of=/dev/sda bs=4M
sync
reboot
