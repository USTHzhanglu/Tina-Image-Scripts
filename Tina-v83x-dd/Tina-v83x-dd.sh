#!/bin/bash
###################################
select=$1                                                                                                  
counter=0
###################################

###################################
device=$2
device=${device:-/dev/sdb}
out_dir=$3
out_dir=${out_dir:-out}
img_name=tina_v831-sipeed_uart0.dd.img
root_part=3
udisk_part=4
sector_size=512
mkdir -p $out_dir
p1_start=`sudo fdisk -l $device |grep ${device}1 |awk '{print $2}'`
p1_end=`sudo fdisk -l $device |grep ${device}1 |awk '{print $3}'`

p2_start=`sudo fdisk -l $device |grep ${device}2 |awk '{print $2}'`
p2_end=`sudo fdisk -l $device |grep ${device}2 |awk '{print $3}'`

p3_start=`sudo fdisk -l $device |grep ${device}3 |awk '{print $2}'`
p3_end=`sudo fdisk -l $device |grep ${device}3 |awk '{print $3}'`
boot_size=$((${p3_start} * $sector_size / 1024 / 1024))
#img_size=`sudo fdisk -l $device |grep ${device} |awk '{print $3}'|sed -n '1p'`
img_size=$((((${p3_end} +1))* ${sector_size} / 1024 / 1024 +10))
#img_size=480
###################################

###################################
system_backup()
{

((++counter)) && echo "[$counter]---now create img,waiting---"
sudo dd if=/dev/zero of=${out_dir}/${img_name} bs=1M count=${img_size} status=progress
((++counter)) && echo "[$counter]---now copy boot,waiting---"
sudo dd if=${device} of=${out_dir}/${img_name} bs=1M count=${boot_size} status=progress  conv=notrunc
echo -e "d\n${udisk_part}\nd\n${root_part}\nw\ny\n"|sudo gdisk ${out_dir}/${img_name}
((++counter)) && echo "[$counter]-- create loop device"
sudo losetup -d /dev/loop404 
sudo losetup -P /dev/loop404 ${out_dir}/${img_name}


((++counter)) && echo "[$counter]-- create part"
(echo -e "n\n${root_part}\n${p3_start}\n${p3_end}\n"
sleep 1
echo -e "x\nn\n${root_part}\nrootfs\nu\n${root_part}\nA0085546-4166-744A-A353-FCA9272B8E48\nr\nw\n"
)|sudo fdisk /dev/loop404

((++counter)) && echo "[$counter]-- create UUID"
(echo -e "x\nu\n${root_part}\nA0085546-4166-744A-A353-FCA9272B8E48\nr\nw\n"
)|sudo fdisk /dev/loop404

((++counter)) && echo "[$counter]-- mkfs part"
sudo mkfs.ext4 /dev/loop404p${root_part}
sudo e2fsck -fyC 0 /dev/loop404p${root_part}
sudo resize2fs -p /dev/loop404p${root_part} 

((++counter)) && echo "[$counter]-- mount"
mkdir -p ${out_dir}/old
mkdir -p ${out_dir}/new
sudo umount ${device}${root_part}
sudo mount -t ext4 ${device}${root_part} ${out_dir}/old
sudo mount -t ext4 /dev/loop404p${root_part} ${out_dir}/new

((++counter)) && echo "[$counter]---now copy rootfs,waiting---"
(cd ${out_dir}/old;sudo tar -cf - .)|(cd ${out_dir}/new;sudo tar -xf -)
sync

((++counter)) && echo "[$counter]-- delete loop device"
sudo umount ${out_dir}/old
sudo umount ${out_dir}/new
sudo kpartx -d /dev/loop404
sudo losetup -d /dev/loop404

((++counter)) && echo "[$counter]---Compressing img,waiting---"
cd ${out_dir}
sudo rm -r ${img_name}.xz
sudo xz -z -k ${img_name} --threads=0
cd -
sudo rm -rf ${out_dir}/old
sudo rm -rf ${out_dir}/new
echo "====================="
echo -e "\033[32m \033[05m \nbackup complete\n \033[0m"
echo "====================="
}
###################################

###################################
system_restore()
{
xz -dc ${out_dir}/${img_name}.xz |sudo dd of=${device} bs=1M status=progress oflag=direct
echo -e "w\n"|sudo fdisk ${device}
sudo e2fsck -fyC 0 ${device}${root_part}
echo "====================="
echo -e "\033[32m \033[05m \nrestore complete\n \033[0m"
echo "====================="
}

###################################

###################################
menu()
{
echo "==========================================================================="
echo -e "cmd=${select} device=${device},out_dir=${out_dir}, img_name is ${img_name}
use \033[32m \033[05m sh backup xxx xxx xxx \033[0m to backup system
    \033[32m \033[05m sh restore xxx xxx xxx \033[0m to restore system
==========================================================================="
if [ "$select" = "backup" ];then
	system_backup
elif [ "$select" = "restore" ];then
	system_restore
fi
}
###################################
menu
