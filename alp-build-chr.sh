#!/bin/sh
touch /root/kriszos-vendor.log
echo "install packages"  >> /root/kriszos-vendor.log
apk add qemu-img curl rsync gptfdisk dosfstools  >> /root/kriszos-vendor.log
echo "download" >> /root/kriszos-vendor.log
wget --no-check-certificate https://download.mikrotik.com/routeros/7.11beta4/chr-7.11beta4.img.zip -O /run/chr.img.zip >> /root/kriszos-vendor.log
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.8/chr-7.8.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.5/chr-7.5.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.3beta40/chr-7.3beta40.img.zip -O /run/chr.img.zip
#wget --no-check-certificate https://download.mikrotik.com/routeros/7.3beta40/chr-7.3beta40.vhdx -O /run/chr.img
echo "unzip" >> /root/kriszos-vendor.log
unzip -p /run/chr.img.zip > /run/chr.img >> /root/kriszos-vendor.log
echo "convert raw to qcow2" >> /root/kriszos-vendor.log
qemu-img convert -f raw -O qcow2 /run/chr.img /root/chr.qcow2 >> /root/kriszos-vendor.log
#qemu-img convert -f vhdx -O qcow2 /run/chr.img chr.qcow2
echo "remove raw image" >> /root/kriszos-vendor.log
modprobe nbd max_part=8 >> /root/kriszos-vendor.log
echo "connect image as /dev/nbd0" >> /root/kriszos-vendor.log
qemu-nbd -c /dev/nbd0 chr.qcow2 >> /root/kriszos-vendor.log
echo "create tmp directories" >> /root/kriszos-vendor.log
mkdir /run/tmpmount/ >> /root/kriszos-vendor.log
mkdir /run/tmpefipart/ >> /root/kriszos-vendor.log
echo "mount first partition" >> /root/kriszos-vendor.log
mount /dev/nbd0p1 /run/tmpmount/ >> /root/kriszos-vendor.log
echo "copy efi/boot files from first partition" >> /root/kriszos-vendor.log
rsync -a /run/tmpmount/ /run/tmpefipart/ >> /root/kriszos-vendor.log
echo "umount first partition" >> /root/kriszos-vendor.log
umount /dev/nbd0p1 >> /root/kriszos-vendor.log
echo "format first partion as fat32" >> /root/kriszos-vendor.log
mkfs.fat /dev/nbd0p1 >> /root/kriszos-vendor.log
echo "mount first partition" >> /root/kriszos-vendor.log
mount -t vfat /dev/nbd0p1 /run/tmpmount/ >> /root/kriszos-vendor.log
echo "copy efi/boot files to first partition" >> /root/kriszos-vendor.log
rsync -a /run/tmpefipart/ /run/tmpmount/ >> /root/kriszos-vendor.log
echo "umount first partition" >> /root/kriszos-vendor.log
umount /dev/nbd0p1 >> /root/kriszos-vendor.log
echo "mount second partition" >> /root/kriszos-vendor.log
mount /dev/nbd0p2 /run/tmpmount/ >> /root/kriszos-vendor.log
#echo
#echo "in 5 seconds you can modify initial config of chr"
#sleep 5
#cat initial.rsc > /run/tmpmount/rw/autorun.scr
#cat import-p1.rsc > /run/tmpmount/rw/autorun.scr
echo "curl from lxd user-data" >> /root/kriszos-vendor.log
curl -s --unix-socket /dev/lxd/sock lxd/1.0/config/cloud-init.user-data >> /run/tmpmount/rw/autorun.scr
#nano /run/tmpmount/rw/autorun.scr
echo "umount second partition" >> /root/kriszos-vendor.log
umount /dev/nbd0p2 >> /root/kriszos-vendor.log
echo "modify partition table" >> /root/kriszos-vendor.log
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
) | gdisk /dev/nbd0 >> /root/kriszos-vendor.log
echo "disconnect image from /dev/nbd0" >> /root/kriszos-vendor.log
qemu-nbd -d /dev/nbd0 >> /root/kriszos-vendor.log
echo "script finished, created file chr.qcow2" >> /root/kriszos-vendor.log
#qemu-img convert -f qcow2 -O vhdx chr.qcow2 chr.vhdx
echo "convert to img" >> /root/kriszos-vendor.log
qemu-img convert -f qcow2 -O raw chr.qcow2 chr.img >> /root/kriszos-vendor.log
#exit 0
#echo "wait 180 seconds to avoid race condition in cloud-init"
#sleep 180
sync >> /root/kriszos-vendor.log
dd if=chr.img of=/dev/sda bs=4M >> /root/kriszos-vendor.log
sync >> /root/kriszos-vendor.log
reboot
