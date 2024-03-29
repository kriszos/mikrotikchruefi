#!/bin/sh
echo "install packages"
#apk add qemu-img curl rsync gptfdisk dosfstools efibootmgr lsblk
apk add curl rsync gptfdisk dosfstools efibootmgr
#modprobe nbd max_part=8
modprobe vfat
modprobe ext2
modprobe ext3
modprobe ext4
echo "download"
wget --no-check-certificate https://download.mikrotik.com/routeros/7.11beta4/chr-7.11beta4.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.8/chr-7.8.img.zip -O /run/chr.img.zip
echo "unzip"
unzip -p /run/chr.img.zip > /run/chr.img
#echo "convert raw to qcow2"
#qemu-img convert -f raw -O qcow2 /run/chr.img /root/chr.qcow2
#echo "connect image as /dev/nbd0"
#qemu-nbd -c /dev/nbd0 /root/chr.qcow2
echo "connect image as /dev/loop5"
#ls /dev/loop5*
#lsblk
losetup -P /dev/loop5 /run/chr.img
#ls /dev/loop5*
#lsblk
#partprobe /dev/nbd0
partprobe /dev/loop5
echo "create tmp directories"
mkdir /run/tmpmount
mkdir /run/tmpefipart
mkdir /run/tmpmount
mkdir /run/tmpefipart
mkdir /run/tmpmount
mkdir /run/tmpefipart
mkdir /run/tmpmount
mkdir /run/tmpefipart
echo "mount first partition"
#sleep 2
while ! mount -t ext2 /dev/loop5p1 /run/tmpmount/
do
sync
sleep 1
partprobe /dev/loop5
done
#ls /dev/loop5*
#lsblk
echo "copy efi/boot files from first partition"
rsync -a /run/tmpmount/ /run/tmpefipart/
echo "umount first partition"
#umount /dev/nbd0p1
#sleep 2
#ls /dev/loop5*
#lsblk
while ! umount /run/tmpmount
do
sync
sleep 1
partprobe /dev/loop5
done
#sleep 2
partprobe /dev/loop5
#ls /dev/loop5*
sync
#lsblk
sync
echo "format first partion as fat32"
#mkfs.fat /dev/loop5p1
while ! mkfs.vfat /dev/loop5p1
do
sync
sleep 1
partprobe /dev/loop5
done
#sleep 2
partprobe /dev/loop5
#ls /dev/loop5*
#lsblk
echo "mount first partition"
#sleep 2
while ! mount -t vfat /dev/loop5p1 /run/tmpmount/
do
sync
sleep 1
partprobe /dev/loop5
done
#ls /dev/loop5*
#lsblk
echo "copy efi/boot files to first partition"
#sleep 2
rsync -a /run/tmpefipart/ /run/tmpmount/
echo "umount first partition"
#sleep 2
partprobe /dev/loop5
#umount /dev/nbd0p1
#sleep 2
#ls /dev/loop5*
#lsblk
while ! umount /run/tmpmount
do
sync
sleep 1
partprobe /dev/loop5
done
#sleep 2
echo "mount second partition"
#ls /dev/loop5*
#lsblk
partprobe /dev/loop5
#sleep 2
#ls /dev/loop5*
#lsblk
while ! mount -t ext4 /dev/loop5p2 /run/tmpmount/
do
sync
sleep 1
partprobe /dev/loop5
done
#sleep 2
#ls /dev/loop5*
#lsblk
partprobe /dev/loop5
#ls /dev/loop5*
#lsblk
echo "curl from lxd user-data"
curl -s --unix-socket /dev/lxd/sock lxd/1.0/config/cloud-init.user-data >> /run/tmpmount/rw/autorun.scr
#nano /run/tmpmount/rw/autorun.scr
echo "umount second partition"
#sleep 2
partprobe /dev/loop5
#ls /dev/loop5*
#lsblk
#umount /dev/nbd0p2
#sleep 2
while ! umount /run/tmpmount
do
sync
sleep 1
partprobe /dev/loop5
done
#ls /dev/loop5*
#lsblk
partprobe /dev/loop5
#ls /dev/loop5*
#lsblk
#sleep 2
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
) | gdisk /dev/loop5
partprobe /dev/loop5
sync
echo "disconnect image from /dev/loop5"
#qemu-nbd -d /dev/loop5
losetup -d /dev/loop5
partprobe /dev/loop5
echo "script finished, created file chr.qcow2"
#qemu-img convert -f qcow2 -O vhdx chr.qcow2 chr.vhdx
#echo "convert to img"
#qemu-img convert -f qcow2 -O raw /root/chr.qcow2 /root/chr.img
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
dd if=/run/chr.img of=/dev/sda bs=4M
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
reboot
