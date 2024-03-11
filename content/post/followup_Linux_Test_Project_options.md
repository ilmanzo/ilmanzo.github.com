---
layout: post
title: "Linux Test Project part 2"
description: "How the Linux Kernel is tested, one syscall at a time"
categories: linux
tags: [linux, sysadmin, opensuse, test, kernel, syscalls]
author: Andrea Manzini
date: 2024-04-01
draft: true
---

## 🕵️ Intro

In the [last post](https://ilmanzo.github.io/post/first_steps_of_ltp_linux_test_project/) we only mentioned the most important part of a LTP test. In this articlem, we are going to describe the options available in the `struct tst_test`.

The [Linux Test Project](https://github.com/linux-test-project/ltp) is a joint project started  years ago by SGI, OSDL and Bull developed and now maintained by IBM, Cisco, Fujitsu, SUSE, Red Hat, Oracle and many others. The project goal is to deliver tests to the open source community that validate the reliability, robustness, and stability of Linux. 

## Talk is cheap

The struct itself is pretty well commented, we are going to highlight the most important stuff. For the rest, please consult documentation (TODO: link) 

{{< highlight C "linenos=table">}}
struct tst_test {
	/* number of tests available in test() function */
	unsigned int tcnt;

	struct tst_option *options;

	const char *min_kver;

	/*
	 * The supported_archs is a NULL terminated list of archs the test
	 * does support.
	 */
	const char *const *supported_archs;

	/* If set the test is compiled out */
	const char *tconf_msg;

	int needs_tmpdir:1;
	int needs_root:1;
	int forks_child:1;
	int needs_device:1;
	int needs_checkpoints:1;
	int needs_overlay:1;
	int format_device:1;
	int mount_device:1;
	int needs_rofs:1;
	int child_needs_reinit:1;
	int needs_devfs:1;
	int restore_wallclock:1;

	/*
	 * If set the test function will be executed for all available
	 * filesystems and the current filesystem type would be set in the
	 * tst_device->fs_type.
	 *
	 * The test setup and cleanup are executed before/after __EACH__ call
	 * to the test function.
	 */
	int all_filesystems:1;

	int skip_in_lockdown:1;
	int skip_in_secureboot:1;
	int skip_in_compat:1;

	/*
	 * If set, the hugetlbfs will be mounted at .mntpoint.
	 */
	int needs_hugetlbfs:1;

	/*
	 * The skip_filesystems is a NULL terminated list of filesystems the
	 * test does not support. It can also be used to disable whole class of
	 * filesystems with a special keywords such as "fuse".
	 */
	const char *const *skip_filesystems;

	/* Minimum number of online CPU required by the test */
	unsigned long min_cpus;

	/* Minimum size(MB) of MemAvailable required by the test */
	unsigned long min_mem_avail;

	/* Minimum size(MB) of SwapFree required by the test */
	unsigned long min_swap_avail;

	/*
	 * Two policies for reserving hugepage:
	 *
	 * TST_REQUEST:
	 *   It will try the best to reserve available huge pages and return the number
	 *   of available hugepages in tst_hugepages, which may be 0 if hugepages are
	 *   not supported at all.
	 *
	 * TST_NEEDS:
	 *   This is an enforced requirement, LTP should strictly do hpages applying and
	 *   guarantee the 'HugePages_Free' no less than pages which makes that test can
	 *   use these specified numbers correctly. Otherwise, test exits with TCONF if
	 *   the attempt to reserve hugepages fails or reserves less than requested.
	 *
	 * With success test stores the reserved hugepage number in 'tst_hugepages. For
	 * the system without hugetlb supporting, variable 'tst_hugepages' will be set to 0.
	 * If the hugepage number needs to be set to 0 on supported hugetlb system, please
	 * use '.hugepages = {TST_NO_HUGEPAGES}'.
	 *
	 * Also, we do cleanup and restore work for the hpages resetting automatically.
	 */
	struct tst_hugepage hugepages;

	/*
	 * If set to non-zero, call tst_taint_init(taint_check) during setup
	 * and check kernel taint at the end of the test. If all_filesystems
	 * is non-zero, taint check will be performed after each FS test and
	 * testing will be terminated by TBROK if taint is detected.
	 */
	unsigned int taint_check;

	/*
	 * If set non-zero denotes number of test variant, the test is executed
	 * variants times each time with tst_variant set to different number.
	 *
	 * This allows us to run the same test for different settings. The
	 * intended use is to test different syscall wrappers/variants but the
	 * API is generic and does not limit the usage in any way.
	 */
	unsigned int test_variants;

	/* Minimal device size in megabytes */
	unsigned int dev_min_size;

	/* Device filesystem type override NULL == default */
	const char *dev_fs_type;

	/* Options passed to SAFE_MKFS() when format_device is set */
	const char *const *dev_fs_opts;
	const char *const *dev_extra_opts;

	/* Device mount options, used if mount_device is set */
	const char *mntpoint;
	unsigned int mnt_flags;
	void *mnt_data;

	/*
	 * Maximal test runtime in seconds.
	 *
	 * Any test that runs for more than a second or two should set this and
	 * also use tst_remaining_runtime() to exit when runtime was used up.
	 * Tests may finish sooner, for example if requested number of
	 * iterations was reached before the runtime runs out.
	 *
	 * If test runtime cannot be know in advance it should be set to
	 * TST_UNLIMITED_RUNTIME.
	 */
	int max_runtime;

	void (*setup)(void);
	void (*cleanup)(void);

	void (*test)(unsigned int test_nr);
	void (*test_all)(void);

	/* Syscall name used by the timer measurement library */
	const char *scall;

	/* Sampling function for timer measurement testcases */
	int (*sample)(int clk_id, long long usec);

	/* NULL terminated array of resource file names */
	const char *const *resource_files;

	/* NULL terminated array of needed kernel drivers */
	const char * const *needs_drivers;

	/*
	 * {NULL, NULL} terminated array of (/proc, /sys) files to save
	 * before setup and restore after cleanup
	 */
	const struct tst_path_val *save_restore;

	/*
	 * {} terminated array of ulimit resource type and value.
	 */
	const struct tst_ulimit_val *ulimit;

	/*
	 * NULL terminated array of kernel config options required for the
	 * test.
	 */
	const char *const *needs_kconfigs;

	/*
	 * {NULL, NULL} terminated array to be allocated buffers.
	 */
	struct tst_buffers *bufs;

	/*
	 * {NULL, NULL} terminated array of capability settings
	 */
	struct tst_cap *caps;

	/*
	 * {NULL, NULL} terminated array of tags.
	 */
	const struct tst_tag *tags;

	/* NULL terminated array of required commands */
	const char *const *needs_cmds;

	/* Requires a particular CGroup API version. */
	const enum tst_cg_ver needs_cgroup_ver;

	/* {} terminated array of required CGroup controllers */
	const char *const *needs_cgroup_ctrls;
};
{{< / highlight >}}

## 

- line 3: this is the number of the tests that the program contains. If you are using a data-driven approach with many test cases in an array, you want to have this number equal to the array size.

- line 5: a pointer to a null-terminated list of options (TODO)

- line 7: a string describing the minimum kernel version needed for this test. When run on an older one, LTP will automatically exclude this test with an appropriate message

- line 13:

- line 16:

- lines 18-48: set of boolean flags that enables specific LTP behaviour. For example if `needs_tmpdir` is `true`, LTP will automatically create a temporary directory for our program data.


- line 135-136: pointers to the `setup` and `clean` functions that will be called only once, before and after the test run 

- line 138-139: mutually exclusive pointers to the actual test code. The first accepts an integer number, useful when you have many test cases for the same function. If the test is a single case, you can use the the second one 

- line 168: array of kconfig options required; when the test is run on a kernel missing some requirement, LTP will skip the test with a message.

- line 173: if your test 


## ✅ Conclusion

If you are interested in the project, check out [the project's Wiki](https://github.com/linux-test-project/ltp/wiki) for other documentation and Writing Guidelines; you can also subscribe to [the LTP Mailing List](https://lists.linux.it/listinfo/ltp). Enjoy!


