---
layout: post
title: "First steps with Linux Test Project"
description: "How the Linux Kernel is tested, one syscall at a time"
categories: linux
tags: [linux, sysadmin, opensuse, test, kernel, syscalls]
author: Andrea Manzini
date: 2024-02-10
---

## 🕵️ Intro

The [Linux Test Project](https://github.com/linux-test-project/ltp) is a joint project started  years ago by SGI, OSDL and Bull developed and now maintained by IBM, Cisco, Fujitsu, SUSE, Red Hat, Oracle and many others. The project goal is to deliver tests to the open source community that validate the reliability, robustness, and stability of Linux. 

In these days I'm having a journey on the project so with this article I want to show step by step how to setup the project, how tests are actually written and give you a *quick and dirty* guide to write your first one.

## 🧰 Let's start

NOTE: Since some tests manipulate operating system settings, if you plan to run the entire testsuite it is advisable to keep your workstation clean and setup a separate environment, like a spare pc or a development virtual machine. 

First thing is to install development tools and clone the repository:

```bash
# zypper in -t pattern devel_basis 
or 
# zypper install gcc git make pkg-config autoconf automake bison flex m4 linux-glibc-devel glibc-devel

$ git clone https://github.com/linux-test-project/ltp.git && cd ltp
$ make autotools 
$ ./configure
[...omitted output...]
```

Now you can continue either with compiling and running a single test or with compiling and installing the whole testsuite. Lets' do one baby step:

## ⚗️ One sample test

If you want to just execute a single test you actually do not need to compile the whole LTP project, so we pick up an example test for the [`open()` syscall](https://man7.org/linux/man-pages/man2/open.2.html) . To find this specific test, 

```bash
$ cd testcases/kernel/syscalls/open
$ cat open03.c
```

### What's inside ⁉️

{{< highlight C "linenos=table">}}
// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) Linux Test Project, 2001-2024
 * Copyright (c) 2000 Silicon Graphics, Inc.  All Rights Reserved.
 */

/*\
 * [Description]
 *
 * Testcase to check open() with O_RDWR | O_CREAT.
 */

#include "tst_test.h"

#define TEST_FILE "testfile"

static void verify_open(void)
{
        TST_EXP_FD(open(TEST_FILE, O_RDWR | O_CREAT, 0700));
        SAFE_CLOSE(TST_RET);
        SAFE_UNLINK(TEST_FILE);
}

static struct tst_test test = {
        .needs_tmpdir = 1,
        .test_all = verify_open,
};
{{< / highlight >}}

This test is pretty simple, as actual code is less than 10 lines. A brief line-by-line overview:

 - 1-12: standard comments, license and doc header. This project has more than 20 years of history!
 - 13: include the mandatory LTP library header
 - 15: a sample filename we'll try to create calling the `open()` syscall
 - 17-19: the real test function: using the macros provided by the framework, send to the kernel  an `open()` syscall and ensure the operation succeeds ; if by any means the syscall should return an error, the error gets automatically reported and the test result marked as *failed*. In any case, the value returned is stored in the variable `TST_RET`
 - 20-22: `SAFE_*` macros let us to close and delete the file just opened in a clean way
 - 24-27: definition for the test metadata: which options does it need to run and which is the function that the framework will execute for us. LTP framework will look for this structure and use the informations inside. If you are curious about all the available options, you can find a good [description here](https://ltp-core.readthedocs.io/en/latest/#customize-test-options), but since it's a big topic, it deserves a future dedicated post

The  [Linux Test Project](https://github.com/linux-test-project/ltp), like the Linux Kernel itself, makes heavy use of C macros, in order to keep the tests clean, mainteinable and readable. Of course all the macros and library functions are documented and explained in the project documentation.

For a reference of the syscalls, just consult your system's **man pages**. As a tip, it's recommended to clone the [upstream man repository](git://git.kernel.org/pub/scm/docs/man-pages/man-pages.git) because sometimes the man pages packaged by distributions can be sometimes lacking behind.

## 👟 How to run the test

Thanks to the build system setup, we can just `make` our single testcase and run the standalone executable. LTP will add lots of useful information to our little program:

```bash
$ make open03
[... compiler messages omitted...]
$ ./open03
tst_test.c:1741: TINFO: LTP version: 20240129
tst_test.c:1625: TINFO: Timeout per run is 0h 00m 30s
open03.c:19: TPASS: open(TEST_FILE, O_RDWR | O_CREAT, 0700) returned fd 3

Summary:
passed   1
failed   0
broken   0
skipped  0
warnings 0
```

The compiled executable is also accepting some options, again courtesy of the LTP framework:

```bash
$ ./open03 -h
Environment Variables
---------------------
KCONFIG_PATH         Specify kernel config file
KCONFIG_SKIP_CHECK   Skip kernel config check if variable set (not set by default)
LTPROOT              Prefix for installed LTP (default: /opt/ltp)
LTP_COLORIZE_OUTPUT  Force colorized output behaviour (y/1 always, n/0: never)
LTP_DEV              Path to the block device to be used (for .needs_device)
LTP_DEV_FS_TYPE      Filesystem used for testing (default: ext2)
LTP_SINGLE_FS_TYPE   Testing only - specifies filesystem instead all supported (for .all_filesystems)
LTP_TIMEOUT_MUL      Timeout multiplier (must be a number >=1)
LTP_RUNTIME_MUL      Runtime multiplier (must be a number >=1)
LTP_VIRT_OVERRIDE    Overrides virtual machine detection (values: ""|kvm|microsoft|xen|zvm)
TMPDIR               Base directory for template directory (for .needs_tmpdir, default: /tmp)

Timeout and runtime
-------------------
Test timeout (not including runtime) 0h 0m 30s

Options
-------
-h       Prints this help
-i n     Execute test n times
-I x     Execute test for n seconds
-D       Prints debug information
-V       Prints LTP version
-C ARG   Run child process with ARG arguments (used internally)
```

you can also check your source code against project best practices:

```bash
$ make check-open03
```
You will receive hints and errors about code quality, formatting and possible deviations from the projects' coding standards.

## 🗿 Hello, new test 

So if you want to write a new LTP test, you can just choose a `testcases/kernel/` subfolder and create a new `.c` file using a template like this:

{{< highlight C "linenos=table">}}
#include <tst_test.h>

static void setup(void) {
        // your setup code goes here
        tst_res(TINFO, "example setup");
}

static void cleanup(void) {
        // your cleanup code goes here
        tst_res(TINFO, "example cleanup");
}

static void run(void) {
        // your test code goes here
        tst_res(TPASS, "Doing hardly anything is easy");
}

static struct tst_test test = {
        .test_all = run,
        .setup = setup,
        .cleanup = cleanup,
};
{{< / highlight >}}

In this example it's important to notice that the functions `setup()` and `cleanup()` are meant to create/dispose test resources (like buffers, files, sockets, child processes and so on) and they get executed only once, while the `run()` is the real test code and can be repeated many times.

After saving your source code with a name like `mynewtest01.c`, you just need to run

```bash
$ make mynewtest01
CC testcases/kernel/syscalls/open/mynewtest01
ls -l mynewtest*
-rwxr-xr-x 1 andrea andrea 738064 Feb 10 11:46 mynewtest01
-rw-r--r-- 1 andrea andrea    475 Feb 10 11:46 mynewtest01.c
./mynewtest01
tst_test.c:1741: TINFO: LTP version: 20240129
tst_test.c:1625: TINFO: Timeout per run is 0h 00m 30s
mynewtest01.c:5: TINFO: example setup
mynewtest01.c:15: TPASS: Doing hardly anything is easy
mynewtest01.c:10: TINFO: example cleanup

Summary:
passed   1
failed   0
broken   0
skipped  0
warnings 0
```

It doesn't do anything yet but seems working, now you need only to actually implement your test logic.

Once finished and debugged, if you want the new test executed as part of the testsuite, you need to add it in one of the `runtest` subfolders, where each text file defines a group of tests AKA test suite. 

## ✅ Conclusion

If you are interested in the project, check out [the project's Wiki](https://github.com/linux-test-project/ltp/wiki) for other documentation and Writing Guidelines; you can also subscribe to [the LTP Mailing List](https://lists.linux.it/listinfo/ltp). Enjoy!


