---
layout: post
title: "debugging a problematic build"
description: "a technique to follow build process"
categories: linux
tags: [linux, programming, testing, nim, building, obs, ]
author: Andrea Manzini
date: 2023-03-14
---

Today it's [PI Day](https://en.wikipedia.org/wiki/Pi_Day), and among other activities I decided to submit an openSUSE package update for the [nim compiler](https://nim-lang.org/). 
It went almost all well but unfortunately I faced a problem: on the i586 platform it fails to build. 

<!--more-->

In this particolar situation, [Open Build Service](https://build.opensuse.org/) logs were not so useful. They only says that the vm running the build was terminated after 5400 seconds of inactivity, meaning that something got stuck and the system waited a lot before terminating the process:


    [ 6748s] qemu-kvm: terminating on signal 15 from pid 14593 (<unknown process>)
    [ 6748s] ### VM INTERACTION END ###
    [ 6748s] No buildstatus set, either the base system is broken (kernel/initrd/udev/glibc/bash/perl)
    [ 6748s] or the build host has a kernel or hardware problem...


    Job seems to be stuck here, killed. (after 5400 seconds of inactivity)

So I tried to reproduce the problem on my local system:

{{< highlight bash >}}
$ osc build openSUSE_Factory i586
{{</ highlight >}}

After some output, it hangs running the unit test suite; so it's a reproducible issue, but still we don't know the reason. 
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
osc build openSUSE_Factory i586 --clean -x procps -x psmisc -x psutils -x iproute2 -x telnet-server --shell-after-fail --vm-telnet 8023
{{</ highlight >}}

I added the luxury of running `top` in the virtual machine; I mean, why not ? :) 
After running the build command, we are free to `telnet localhost 8023` and get a root shell inside our building environment.

# We are inside! 
Once here, it's simple to make it reach the hanging step, detect the problem from inside and solve with a simple fix in the `.spec` file, which means in this instance to exclude two special test cases from running in a 32 bit networkless system.
