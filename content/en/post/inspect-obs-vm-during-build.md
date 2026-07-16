---
layout: post
title: "Debugging a problematic build"
description: "A technique to inspect Open Build Service build process"
categories: linux
tags: [linux, programming, testing, nim, building, obs, ]
author: Andrea Manzini
date: 2023-03-14
---

# The Good  :innocent:
Today I decided to submit an openSUSE package update for the [nim compiler](https://nim-lang.org/). 
It went almost all well but unfortunately I faced a problem: on the i586 platform it fails to build. 

<!--more-->

In this particolar situation, [Open Build Service](https://build.opensuse.org/) logs were not so useful. They only says that the vm running the build was terminated after 5400 seconds of inactivity, meaning that something got stuck and the system kindly waited a lot before terminating the process:

# The Bad :sweat:

    [ 6748s] qemu-kvm: terminating on signal 15 from pid 14593 (<unknown process>)
    [ 6748s] ### VM INTERACTION END ###
    [ 6748s] No buildstatus set, either the base system is broken (kernel/initrd/udev/glibc/bash/perl)
    [ 6748s] or the build host has a kernel or hardware problem...


    Job seems to be stuck here, killed. (after 5400 seconds of inactivity)

So as a first move, I try to reproduce the problem on my local system:

{{< highlight bash >}}
$ osc build openSUSE_Factory i586
{{</ highlight >}}

(You may need to change the `openSUSE_Factory` parameter with one of the repositories you are building for, configured at project level)

After some output, it hangs running the unit test suite; good news because means it's a reproducible issue, but still *we don't know the reason*. 

# The Ugly :frowning:

Build happens inside a qemu-kvm virtual machine, which is spawned and killed on demand; can we break inside this vm ?
Well, we could leverage the **QEMU Monitor** to send commands via an *Unix Socket*, but there's another solution: `osc` has a cool option to start a telnet server in the build system.

{{< highlight bash >}}
$ osc build openSUSE_Factory i586 --vm-telnet 8023
{{</ highlight >}}

    now finalizing build dir...
    ... running 01-add_abuild_user_to_trusted_group
    ... running 02-set_timezone_to_utc
    ... running 03-set-permissions-secure
    ... running 11-hack_uname_version_to_kernel_version
    ERROR: neither /sbin/ifconfig nor /sbin/ip is installed, please specify correct package via -x option
    [    6.402979][    T1] sysrq: Power Off
    [    6.414858][  T165] reboot: Power down

Close enough, seems we only need to add some missing packages to the build virtual machine.

{{< highlight bash >}}
$ osc build openSUSE_Factory i586 --clean -x procps -x psmisc -x psutils -x iproute2 -x telnet-server --shell-after-fail --vm-telnet 8023
{{</ highlight >}}

I added the luxury of running `top` in the virtual machine; I mean, why not ? :smiley_cat:
After running the build command, we are free to `telnet localhost 8023` and get a root shell inside our building environment.

# We are inside! :grin:
Once here, it's simple to make the build reach the hanging step, detect the problem from inside and solve with a simple fix in the `.spec` file. 
In this instance we need to exclude two GC test cases because they seems not running in a 32 bit networkless system, which is also worth to report upstream.

# Post Scriptum:
Today it's [PI Day](https://en.wikipedia.org/wiki/Pi_Day); Enjoy!