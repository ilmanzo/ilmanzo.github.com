---
layout: post
title: "Linux Test Project part 2"
description: "Follow-up on LTP: the test options"
categories: linux
tags: [linux, sysadmin, opensuse, test, kernel, syscalls]
author: Andrea Manzini
date: 2024-10-27
---

## 👻 Intro

While our [previous post](https://ilmanzo.github.io/post/first_steps_of_ltp_linux_test_project/) focused on the core components of LTP tests, today in this part ~~boo~~ two we're taking a spooky deep dive into the options available in `struct tst_test` 🦇.

The [Linux Test Project (LTP)](https://github.com/linux-test-project/ltp) began as a collaborative effort between SGI, OSDL, and Bull. Today, it lives with the joint contributions of industry leaders including IBM, Cisco, Fujitsu, SUSE, Red Hat, Oracle, and others. Its mission remains clear: providing the open source community with comprehensive tests that verify Linux's reliability, robustness, and stability. 🕸️

## 🍭 Talk is cheap, show me the code

The struct itself is pretty well commented, so we are going to highlight the most important stuff. For the rest, please consult the [documentation](https://linux-test-project.readthedocs.io/en/latest/developers/api_c_tests.html#struct-tst-test)

{{< highlight C "linenos=table">}}
struct tst_test {
    unsigned int tcnt;
    struct tst_option *options;
    const char *min_kver;
    const char *const *supported_archs;
    const char *tconf_msg;
    unsigned int needs_tmpdir:1;
    unsigned int needs_root:1;
    unsigned int forks_child:1;
    unsigned int needs_device:1;
    unsigned int needs_checkpoints:1;
    unsigned int needs_overlay:1;
    unsigned int format_device:1;
    unsigned int mount_device:1;
    unsigned int needs_rofs:1;
    unsigned int child_needs_reinit:1;
    unsigned int runs_script:1;
    unsigned int needs_devfs:1;
    unsigned int restore_wallclock:1;
    unsigned int all_filesystems:1;
    unsigned int skip_in_lockdown:1;
    unsigned int skip_in_secureboot:1;
    unsigned int skip_in_compat:1;
    int needs_abi_bits;
    unsigned int needs_hugetlbfs:1;
    const char *const *skip_filesystems;
    unsigned long min_cpus;
    unsigned long min_mem_avail;
    unsigned long min_swap_avail;
    struct tst_hugepage hugepages;
    unsigned int taint_check;
    unsigned int test_variants;
    unsigned int dev_min_size;
    struct tst_fs *filesystems;
    const char *mntpoint;
    int max_runtime;
    void (*setup)(void);
    void (*cleanup)(void);
    void (*test)(unsigned int test_nr);
    void (*test_all)(void);
    const char *scall;
    int (*sample)(int clk_id, long long usec);
    const char *const *resource_files;
    const char * const *needs_drivers;
    const struct tst_path_val *save_restore;
    const struct tst_ulimit_val *ulimit;
    const char *const *needs_kconfigs;
    struct tst_buffers *bufs;
    struct tst_cap *caps;
    const struct tst_tag *tags;
    const char *const *needs_cmds;
    const enum tst_cg_ver needs_cgroup_ver;
    const char *const *needs_cgroup_ctrls;
    int needs_cgroup_nsdelegate:1;
};
{{< / highlight >}}

## 

- line 2: this is the number of the tests that the program contains. If you are using a data-driven approach with many test cases in an array, you want to have this number equal to the array size.

- line 3: a pointer to a null-terminated list of options (TODO)

- line 4: a string describing the minimum kernel version needed for this test. When run on an older one, LTP will automatically exclude this test with an appropriate message

- line 5: A NULL terminated array of architectures the test runs on e.g. {"x86_64", "x86", NULL}.

- line 6: If set the test exits with TCONF right after entering the test library. This is used by the TST_TEST_TCONF() macro to disable tests at compile time.

- lines 7-23: set of boolean flags that enables specific LTP behaviour. For example if `needs_tmpdir` is `true`, LTP will automatically create a temporary directory for our program data.

- lines 24-36: set of options that controls when the test runs or not. For example, if `min_cpus=2`, the test won't run on single-core systems.

- line 37-38: pointers to the `setup` and `clean` functions that will be called only once, before and after the test run 

- line 39-40: mutually exclusive pointers to the actual test code. The first accepts an integer number, useful when you have many test cases for the same function. If the test contains just a single case, you can use the the second one. 

- line 41-42: reserved for internal usage.

- line 43: A NULL terminated array of filenames that will be copied to the test temporary directory from the LTP datafiles directory.

- line 48: A description of guarded buffers to be allocated for the test. Guarded buffers are buffers with poisoned page allocated right before the start of the buffer and canary right after the end of the buffer. See struct tst_buffers and tst_buffer_alloc() for detail.

## 🍬 Enough tricks, gimme a treat  

To see a real usage of these options, let's analyze one of the tests. Taking a simple one like the [swapoff](https://man7.org/linux/man-pages/man2/swapon.2.html) syscall; rather than the test itself, we are more interested on the `struct tst_test` usage, but the source it's quite short and reading code is always educational. It's [one of the Free Sofware's four essential freedoms](https://www.gnu.org/philosophy/free-sw.html#four-freedoms), isn't it ? 

```bash
# cat ltp/testcases/kernel/syscalls/swapoff/swapoff01.c
```
{{< highlight C "linenos=table">}}
// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) Wipro Technologies Ltd, 2002.  All Rights Reserved.
 */

/*\
 * [Description]
 *
 * Check that swapoff() succeeds.
 */

#include <unistd.h>
#include <errno.h>
#include <stdlib.h>

#include "tst_test.h"
#include "lapi/syscalls.h"
#include "libswap.h"

#define MNTPOINT	"mntpoint"
#define TEST_FILE	MNTPOINT"/testswap"
#define SWAP_FILE	MNTPOINT"/swapfile"

static void verify_swapoff(void)
{
	if (tst_syscall(__NR_swapon, SWAP_FILE, 0) != 0) {
		tst_res(TFAIL | TERRNO, "Failed to turn on the swap file"
			 ", skipping test iteration");
		return;
	}

	TEST(tst_syscall(__NR_swapoff, SWAP_FILE));

	if (TST_RET == -1) {
		tst_res(TFAIL | TTERRNO, "Failed to turn off swapfile,"
			" system reboot after execution of LTP "
			"test suite is recommended.");
	} else {
		tst_res(TPASS, "Succeeded to turn off swapfile");
	}
}

static void setup(void)
{
	is_swap_supported(TEST_FILE);
	SAFE_MAKE_SWAPFILE_BLKS(SWAP_FILE, 65536);
}

static struct tst_test test = {
	.mntpoint = MNTPOINT,
	.mount_device = 1,
	.dev_min_size = 350,
	.all_filesystems = 1,
	.needs_root = 1,
	.test_all = verify_swapoff,
	.max_runtime = 60,
	.setup = setup
};
{{< / highlight >}}

- lines 1-18: standard license and inclusion of LTP header files.
- lines 20-22: definition of some constant values that will be used in the test
- lines 24-41: the real test function. This function basically calls `swapon()` to create a swapfile (aborting when it fails), then tries to stop swapping on that file checking the result.
- lines 43-47: the `setup()` function, executed just once before the start of the test: check if system supports swapping, then create a small swap file using helper functions.
- lines 49: the definition of the `tst_test` parameters for this test:
- line 50: the test requires a new mountpoint: LTP will take care to create it and destroy at the end
- line 51: LTP will formats the device and mounts at the mountpoint specified above
- line 52: device should be at least 350MB in size
- line 52: detect all the filesystem supported by the kernel and automatically repeats the same test for ALL of them
- line 53: this test needs to be run as root. When run as normal user, the exit code will be TCONF 
- line 54: pointer to the actual test function
- line 55: give 60 seconds to run this test. When exceeded, LTP will automatically mark this test with an error
- line 56: pointer to the setup function

## 🦸 Run run run
Let's run this test on a [openSUSE](https://www.opensuse.org/) virtual machine:

```bash
# cd ltp/testcases/kernel/syscalls/swapoff
# make swapoff01
# ./swapoff01 
tst_tmpdir.c:316: TINFO: Using /tmp/LTP_swaGg5kZE as tmpdir (tmpfs filesystem)
tst_device.c:96: TINFO: Found free device 0 '/dev/loop0'
tst_test.c:1888: TINFO: LTP version: 20240930-44-g34e6dd2d2
tst_test.c:1892: TINFO: Tested kernel: 6.4.0-slfo.1.7-default #1 SMP PREEMPT_DYNAMIC Tue Oct  1 10:57:21 UTC 2024 (0e26fa9) x86_64
tst_test.c:1723: TINFO: Timeout per run is 0h 01m 30s
tst_supported_fs_types.c:97: TINFO: Kernel supports ext2
tst_supported_fs_types.c:62: TINFO: mkfs.ext2 does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports ext3
tst_supported_fs_types.c:62: TINFO: mkfs.ext3 does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports ext4
tst_supported_fs_types.c:62: TINFO: mkfs.ext4 does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports xfs
tst_supported_fs_types.c:58: TINFO: mkfs.xfs does not exist
tst_supported_fs_types.c:97: TINFO: Kernel supports btrfs
tst_supported_fs_types.c:62: TINFO: mkfs.btrfs does exist
tst_supported_fs_types.c:105: TINFO: Skipping bcachefs because of FUSE blacklist
tst_supported_fs_types.c:97: TINFO: Kernel supports vfat
tst_supported_fs_types.c:62: TINFO: mkfs.vfat does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports exfat
tst_supported_fs_types.c:58: TINFO: mkfs.exfat does not exist
tst_supported_fs_types.c:132: TINFO: FUSE does support ntfs
tst_supported_fs_types.c:62: TINFO: mkfs.ntfs does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports tmpfs
tst_supported_fs_types.c:49: TINFO: mkfs is not needed for tmpfs
tst_test.c:1821: TINFO: === Testing on ext2 ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ext2 opts='' extra opts=''
mke2fs 1.47.0 (5-Feb-2023)
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ext2 flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on ext3 ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ext3 opts='' extra opts=''
mke2fs 1.47.0 (5-Feb-2023)
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ext3 flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on ext4 ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ext4 opts='' extra opts=''
mke2fs 1.47.0 (5-Feb-2023)
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ext4 flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on btrfs ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with btrfs opts='' extra opts=''
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=btrfs flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
libswap.c:43: TINFO: FS_NOCOW_FL attribute set on mntpoint/testswap
tst_ioctl.c:21: TINFO: FIBMAP ioctl is NOT supported: EINVAL (22)
libswap.c:128: TINFO: File 'mntpoint/testswap' is not contiguous
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
libswap.c:43: TINFO: FS_NOCOW_FL attribute set on mntpoint/swapfile
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on vfat ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with vfat opts='' extra opts=''
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=vfat flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on ntfs ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ntfs opts='' extra opts=''
The partition start sector was not specified for /dev/loop0 and it could not be obtained automatically.  It has been set to 0.
The number of sectors per track was not specified for /dev/loop0 and it could not be obtained automatically.  It has been set to 0.
The number of heads was not specified for /dev/loop0 and it could not be obtained automatically.  It has been set to 0.
To boot from a device, Windows needs the 'partition start sector', the 'sectors per track' and the 'number of heads' to be set.
Windows will not be able to boot from this device.
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ntfs flags=0
tst_test.c:1183: TINFO: Trying FUSE...
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on tmpfs ===
tst_test.c:1171: TINFO: Skipping mkfs for TMPFS filesystem
tst_test.c:1147: TINFO: Limiting tmpfs size to 350MB
tst_test.c:1183: TINFO: Mounting ltp-tmpfs to /tmp/LTP_swaGg5kZE/mntpoint fstyp=tmpfs flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:21: TINFO: FIBMAP ioctl is NOT supported: EINVAL (22)
libswap.c:228: TCONF: Swapfile on tmpfs not implemented

Summary:
passed   6
failed   0
broken   0
skipped  1
warnings 0
```

As you can see, the test developer needs only to worry about testing the specific feature or functionality, while all the surrounding boilerplate is taken care by LTP framework and utility functions. Very handy!

## 🎃 Conclusion (?)

If you are interested in the LTP project, check out [the project's repository](https://github.com/linux-test-project/ltp) for other documentation and Writing Guidelines; you can also subscribe to [the LTP Mailing List](https://lists.linux.it/listinfo/ltp). 

If you like this kind of drill-down posts and want more, or for any other feedback feel free to drop me a message by email or at [fosstodon](https://fosstodon.org/@ilmanzo). Enjoy!


