#!/bin/bash
###################################
select=$1                                                                                                  
counter=0
device=$2
device=${device:-/dev/sdb}
out_dir=$3
out_dir=${out_dir:-out}
img_name=tina_v831-sipeed_uart0.dd.img
sector_size=512
###################################
if [ "$select" = "backup" ];then
	sudo parted -l > ${out_dir}/parted.log
	mkdir -p $out_dir
	sudo fdisk -l  $device > ${out_dir}/fdisk.log
fi
###################################
root_part=`sudo cat  ${out_dir}/parted.log  |grep rootfs|awk '{print $1}'`
udisk_part=`sudo cat  ${out_dir}/parted.log |grep UDISK|awk '{print $1}'`
tmp=`echo ${device} |cut -d / -f 3`
fstype=`sudo lsblk -f |grep ${tmp}${root_part} |awk '{print $2}' ` #get filesystem type
root_start=`sudo cat  ${out_dir}/fdisk.log|grep ${device}${root_part} |awk '{print $2}'`
root_end=`sudo cat  ${out_dir}/fdisk.log|grep ${device}${root_part} |awk '{print $3}'`

udisk_start=`echo ${fdisklog} |grep ${device}${udisk_part} |awk '{print $2}'`
udisk_end=`echo ${fdisklog} |grep ${device}${udisk_part} |awk '{print $3}'` 

boot_size=$((${root_start} * ${sector_size} / 1024 / 1024))
#img_size=`sudo fdisk -l $device |grep ${device} |awk '{print $3}'|sed -n '1p'`
img_size=$((((${root_end} +1))* ${sector_size} / 1024 / 1024 +10))
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
(echo -e "n\n${root_part}\n${root_start}\n${root_end}\n"
sleep 1
echo -e "x\nn\n${root_part}\nrootfs\nu\n${root_part}\nA0085546-4166-744A-A353-FCA9272B8E48\nr\nw\n"
)|sudo fdisk /dev/loop404

((++counter)) && echo "[$counter]-- create UUID"
(echo -e "x\nu\n${root_part}\nA0085546-4166-744A-A353-FCA9272B8E48\nr\nw\n"
)|sudo fdisk /dev/loop404

((++counter)) && echo "[$counter]-- mkfs part"
sudo mkfs.${fstype} /dev/loop404p${root_part}
sudo e2fsck -fyC 0 /dev/loop404p${root_part}
sudo resize2fs -p /dev/loop404p${root_part} 

((++counter)) && echo "[$counter]-- mount"
mkdir -p ${out_dir}/old
mkdir -p ${out_dir}/new
sudo umount ${device}${root_part}
sudo mount -t ${fstype} ${device}${root_part} ${out_dir}/old
sudo mount -t ${fstype} /dev/loop404p${root_part} ${out_dir}/new

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
system_backup_squashfs()
{

((++counter)) && echo "[$counter]---now copy img,waiting---"
sudo dd if=${device} of=${out_dir}/${img_name} bs=1M count=${img_size} status=progress  conv=notrunc
echo -e "d\n${udisk_part}\nw\ny\n"|sudo gdisk ${out_dir}/${img_name}

((++counter)) && echo "[$counter]---Compressing img,waiting---"
cd ${out_dir}
sudo rm -r ${img_name}.xz
sudo xz -z -k ${img_name} --threads=0
cd -
echo "====================="
echo -e "\033[32m \033[05m \nbackup complete\n \033[0m"
echo "====================="
}
###################################

###################################
system_restore()
{
xz -dc ${out_dir}/${img_name}.xz |sudo dd of=${device} bs=1M status=progress oflag=direct
echo -e "n\n${udisk_part}\n${udisk_start}\n\nx\nn\n5\nUDISK\nr\nw\n"|sudo fdisk ${device}
sudo mkfs.vfat ${device}${udisk_part}
sudo umount ${device}${root_part}
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
echo -e "cmd=${select} device=${device},out_dir=${out_dir}
use \033[32m \033[05m sh backup xxx xxx \033[0m to backup system
    \033[32m \033[05m sh restore xxx xxx \033[0m to restore system
==========================================================================="
if [ "$select" = "backup" ];then
	if [ "${fstype}" = "squashfs" ];then
	echo -e "now use dd to copy bin\n"
		system_backup_squashfs
	else
		system_backup
	fi
elif [ "$select" = "restore" ];then
	system_restore
fi
}
###################################
menu
