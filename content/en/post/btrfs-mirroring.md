+++
author = "Andrea Manzini"
title = "how to setup disk redundancy with BTRFS filesystem"
date = "2014-07-09"
description = "how to setup disk redundancy with BTRFS filesystem"
tags = [
    "btrfs",
    "linux",
    "raid1",
    "tips",
    "storage"
]
categories = [
    "sysadmin"
]
+++



Starting with a plain old one-disk configuration...

{{< highlight bash >}}
# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda2       5.8G  590M  5.0G  11% /data
{{</ highlight >}}

thanks to the power of [btrfs](http://en.wikipedia.org/wiki/Btrfs), let's add a second hard disk, with mirrored data AND without unmounting/reformatting! :)
also note the different size....

{{< highlight bash >}}
# fdisk -l

Disk /dev/sda: 6 GiB, 6442450944 bytes, 12582912 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xea97ecdc

Device    Boot     Start       End  Blocks  Id System
/dev/sda1           2048    526335  262144  82 Linux swap / Solaris
/dev/sda2 *       526336  12582911 6028288  83 Linux


Disk /dev/sdb: 4 GiB, 4294967296 bytes, 8388608 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
{{</ highlight >}}

... state of the filesystem before the change...

{{< highlight bash >}}
# btrfs filesystem show /data
Label: none  uuid: b9ba1a95-1aaf-4c18-96ba-e4512b6f030f
        Total devices 1 FS bytes used 544.04MiB
        devid    1 size 5.75GiB used 912.00MiB path /dev/sda2

{{</ highlight >}}

now we tell the filesystem it has a new disk to use:

{{< highlight bash >}}
# btrfs device add /dev/sdb /data
{{</ highlight >}}

now we need to rebalance the filesystem:

{{< highlight bash >}}
# btrfs balance start -dconvert=raid1 -mconvert=raid1 /data
{{</ highlight >}}

... after some time ...
btrfs will store chunks of data in both disks, evenly distributing the capacity.

{{< highlight bash >}}
#  btrfs filesystem show /data
Label: none  uuid: b9ba1a95-1aaf-4c18-96ba-e4512b6f030f
        Total devices 2 FS bytes used 545.14MiB
        devid    1 size 5.75GiB used 1.27GiB path /dev/sda2
        devid    2 size 4.00GiB used 1.27GiB path /dev/sdb

# btrfs filesystem df /data
Data, RAID1: total=1008.00MiB, used=499.81MiB
System, RAID1: total=32.00MiB, used=16.00KiB
Metadata, RAID1: total=256.00MiB, used=45.48MiB
unknown, single: total=16.00MiB, used=0.00
{{</ highlight >}}

now you're using two disks (RAID1) to store data and metadata!

for a multi-volume filesystem, remember to specify ALL the devices in the fstab entry:

    /dev/sdb     /data    btrfs    device=/dev/sdb,device=/dev/sda2    1 2

should one of the two disks fail, add a new one to the system and replace it:

{{< highlight bash >}}
# btrfs replace start old_disk newdisk /data 
{{</ highlight >}}

If you wish to restore the previous one-single-disk configuration:

{{< highlight bash >}}
# btrfs balance start -f -dconvert=single -mconvert=single /data
# btrfs device delete /dev/sdb /data
{{</ highlight >}}






