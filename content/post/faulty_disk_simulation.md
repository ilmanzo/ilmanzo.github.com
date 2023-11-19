---
layout: post
title: "Expect the unexpected"
description: "How to improve your software by simulating a faulty block device"
categories: linux
tags: [linux, sysadmin, programming, testing, device, storage]
author: Andrea Manzini
date: 2023-11-19
---

## *"You sound like a broken record"* 

Is something we complain when someone repeats again and again the same concepts. But even broken disks can sometime be useful... 

DISCLAIMER: No filesystem or device were harmed in the making of this experiment 😉

![broken-record](/img/pexels-mick-haupt-7663550.jpg)
Image credits: [Mick Haupt](https://www.pexels.com/@mickhaupt/)


In this article I would like to explore the tools we have available in linux to simulate dealing with broken disks, that is, drives that more or less randomly report errors. 
Why is this important ? Because by simulating errors that will also happen sooner or later in the real world, we are able to create software that is more robust and can withstand any problems on the infrastructure. 

## Setup

In order not to create problems in our development system, and to make the process as portable as possible, we start by creating a dummy 1GB disk based on the loop filesystem. 

```bash
# dd if=/dev/zero of=/myfakedisk.bin bs=1M count=1024
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 0.446898 s, 2.4 GB/s

# losetup -P /dev/loop0 blockfile
```

Now we can use the loop device just like any other block device: we can create a filesystem and mount it

```bash
# mkfs.ext4 /dev/loop0
mke2fs 1.46.4 (18-Aug-2021)
Discarding device blocks: done                            
Creating filesystem with 262144 4k blocks and 65536 inodes
Filesystem UUID: bcba505c-54fa-49e5-852c-b5ea3faa53d0
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

# mkdir /mnt/good && mount /dev/loop0 /mnt/good && echo "test" > /mnt/good/test.txt && umount /mnt/good
```

our working "disk" is ready, now we can create a faulty one using linux's [device mapper](https://docs.kernel.org/admin-guide/device-mapper/index.html) features

## What's device mapper ?

![map](/img/pexels-monstera-production-7412095.jpg)
Image credits: [Monstera Production](https://www.pexels.com/@gabby-k/)

The Linux Device Mapper is a kernel-level framework that enables the creation of virtual block devices by mapping physical storage devices or logical volumes to these virtual devices. It operates within the Linux kernel, providing a layer for creating, managing, and manipulating storage devices through various mapping techniques such as mirroring, striping, encryption, and snapshots. This framework allows for the implementation of advanced storage features like volume management, RAID, and thin provisioning, offering greater flexibility, scalability, and reliability in managing storage resources within the Linux operating system.

Basically we are going to create a "map" between our working device and a "new" one, with this schema:

- from sector 0 to 2047, get the data from the underlying device
- from sector 2048 to half disk size, return an error, or the original data, with 20% odds of failure
- from half size to the end, return again the data from the underlying device

Disk size can be found with a simple check:

```bash
# cat /sys/block/loop0/size 
2097152
```

This kind of mapping is expressed in the `dmsetup create` command:

```bash
# dmsetup create bad_disk << EOF
0       2048    linear /dev/loop0 0
2048    1047552 flakey /dev/loop0 2048 4 1 
1049600 1047552 linear /dev/loop0 1049600
EOF

# ls -l /dev/mapper/bad_disk
lrwxrwxrwx 1 root root 7 Nov 19 17:51 /dev/mapper/bad_disk -> ../dm-0
```

For each table entry, we need to specify:
- start sector/offset of mapping
- size of the mapping 
- which mapper is being used
- options of the mapper 

In this setup we are using the [linear](https://docs.kernel.org/admin-guide/device-mapper/linear.html) mapper and the [flakey](https://docs.kernel.org/admin-guide/device-mapper/dm-flakey.html) one. Another useful can be [delay](https://docs.kernel.org/admin-guide/device-mapper/delay.html) to simulate very slow disks or [dust](https://docs.kernel.org/admin-guide/device-mapper/dm-dust.html) that emulates the behavior of bad sectors at arbitrary locations, and the ability to enable the emulation of the failures at an arbitrary time.

## Let's try it out

Our backing disk is already formatted, so it's time to try out the bad one, by mounting and writing some stuff:

```bash
# mkdir /mnt/bad && mount /dev/mapper/bad_disk /mnt/bad && cd /mnt/bad

# df -h | grep -E '(^Filesystem|bad)'
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/bad_disk  974M   28K  907M   1% /mnt/bad

 # while sleep 1 ; do dd if=/dev/zero of=trytowrite.bin bs=1M count=500 ; done 
500+0 records in
500+0 records out
524288000 bytes (524 MB, 500 MiB) copied, 0.595353 s, 881 MB/s
500+0 records in
500+0 records out
524288000 bytes (524 MB, 500 MiB) copied, 0.637194 s, 823 MB/s

Message from syslogd@localhost at Nov 19 18:09:15 ...
 kernel:[ 8017.117593][T23594] EXT4-fs (dm-0): failed to convert unwritten extents to written extents -- potential data loss!  (inode 13, error -30)

Message from syslogd@localhost at Nov 19 18:09:15 ...
 kernel:[ 8017.118445][T23976] EXT4-fs (dm-0): failed to convert unwritten extents to written extents -- potential data loss!  (inode 13, error -30)
dd: error writing 'trytowrite.bin': Read-only file system
481+0 records in
480+0 records out
503865344 bytes (504 MB, 481 MiB) copied, 0.549939 s, 916 MB/s
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
```

## Disk failure is a success! 

As we can see, at first some I/O operations succeeds, then disk fails and in `dmesg` log we can find more details:

```
[ 7962.645178] EXT4-fs (dm-0): error loading journal
[ 7979.334186] EXT4-fs (dm-0): mounted filesystem with ordered data mode. Opts: (null). Quota mode: none.
[ 8016.759602] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129024)
[ 8016.759641] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129280)
[ 8016.759685] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129536)
[ 8016.759802] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129870)
[ 8016.760119] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 130625)
[ 8016.760122] Buffer I/O error on device dm-0, logical block 130625
[ 8016.760129] Buffer I/O error on device dm-0, logical block 130626
[ 8016.760131] Buffer I/O error on device dm-0, logical block 130627
[ 8016.760132] Buffer I/O error on device dm-0, logical block 130628
[ 8016.760133] Buffer I/O error on device dm-0, logical block 130629
[ 8016.760134] Buffer I/O error on device dm-0, logical block 130630
[ 8016.760135] Buffer I/O error on device dm-0, logical block 130631
[ 8016.760136] Buffer I/O error on device dm-0, logical block 130632
[ 8016.760137] Buffer I/O error on device dm-0, logical block 130633
[ 8016.760138] Buffer I/O error on device dm-0, logical block 130634
[ 8016.923667] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 54272)
[ 8016.923731] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 54783)
[ 8016.924020] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 55296)
[ 8016.924335] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 60416)
[ 8016.924394] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 61803)
[ 8016.961108] Buffer I/O error on dev dm-0, logical block 131103, lost sync page write
[ 8016.961125] Aborting journal on device dm-0-8.
[ 8016.961127] Buffer I/O error on dev dm-0, logical block 131072, lost sync page write
[ 8016.961128] JBD2: Error -5 detected when updating journal superblock for dm-0-8.
[ 8016.961142] EXT4-fs error (device dm-0): ext4_journal_check_start:83: comm kworker/u2:3: Detected aborted journal
[ 8016.966200] EXT4-fs error (device dm-0): ext4_journal_check_start:83: comm dd: Detected aborted journal
```

In a more general sense, these concepts fall under the principle of ["chaos engineering"](https://en.wikipedia.org/wiki/Chaos_engineering). 


## Cleanup

To remove the tracks of our experiments, it's sufficient to unmount the "bad" disk, remove the mapping and unassociate the loop device with the backing file. 
```
# umount /mnt/bad && rmdir /mnt/bad
# dmsetup remove bad_disk
# losetup -d /dev/loop0
```


