## 脚本介绍

备份系统的最小启动镜像，即包含env boot rootfs分区的镜像。通过此脚本，可以方便的在不同大小的磁盘上备份还原镜像。但是磁盘最小容量应该大于rootfs。

分区架构应如下，分区表应为GPT

```
Device      Start    End Sectors Name Attrs
/dev/sdb1   49152  49663     512  env  
/dev/sdb2   49664  57855    8192  boot 
/dev/sdb3   57856 844287  786432  rootfs
/dev/sdb4  844288 980991  136704  UDISK
```

其中UDISK镜像不备份。

如果env和boot处在同一个分区,或存在其他分区的，则调整脚本内的

```
root_part=3
udisk_part=4
```

只需要确保rootfs和udisk存在于分区表最后。

## 如何执行


| 脚本参数 |  作用  |输入值      |
| ------------ | ---- | ---- |
|    cmd          |执行命令      |backup/restore |
|      device        | 备份或还原设备所在位置     | 默认/dev/sdb，缺省值    |
|          out_dir          |    导出镜像所在位置         |默认./out，缺省值|

### 备份镜像

```
system_backup.sh backup /dev/sdb out
```

### 还原镜像

```
system_backup.sh restore /dev/sdb
```

