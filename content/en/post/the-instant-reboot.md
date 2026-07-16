---
title: "'uptime' is a Lie: Rebooting without stopping the Kernel"
date: 2025-12-10
author: "Andrea Manzini"
tags: ["linux", "systemd", "sysadmin", "performance"]
categories: ["Linux", "Tutorials"]
summary: "Why wait 10 minutes for a BIOS POST? Exploring systemd-soft-reboot to restart userspace without touching the hardware."
draft: true
---

### The Waiting Game

If you manage physical servers, you know the pain. You run a full system update, you see a new `glibc`, `openssl`, or a critical library in the transaction list, and you sigh. You know what comes next.

You have to reboot.

On modern server hardware, a "reboot" isn't just a quick flicker. It's a 5-to-10-minute ritual of memory training, RAID controller initialization, BIOS POSTs, and waiting for the BMC to finally let the OS take over.

I’m impatient. And usually, I don't actually *need* the hardware to reset. I just need the software to get out of the way and restart fresh.

Enter **`systemd-soft-reboot`**.

### What is it?

Introduced around systemd v254 (and polished in the versions since), `soft-reboot` is a userspace-only reboot. It shuts down all running services, unmounts file systems (where possible), and then **re-executes the systemd manager (PID 1)**.

Crucially, it does **not**:
* Reset the kernel.
* Trigger the BIOS/UEFI POST.
* Wait for hardware initialization.

It’s effectively a "Log out and Log back in" for the entire operating system, happening in seconds rather than minutes.

### The Practical Use Case: "The Library Update"

The most pragmatic use case for a sysadmin is applying core library updates.

Let's say you update `glibc`. In the old days, you'd full reboot to ensure no process is holding onto old file descriptors. With soft-reboot, you flush the entire userspace state and reload everything from disk, picking up the new libraries without the hardware penalty.

### Let's try it out

I spun up a VM to test this. The command is suspiciously simple:

```bash
$ systemctl soft-reboot
```



The system goes down and comes back up almost instantly. But here is the cool part—check the uptime after you log back in:

Bash

$ uptime
 18:23:45 up 4 days, 2:15,  1 user,  load average: 0.15, 0.05, 0.01
The uptime didn't reset. Because the kernel never stopped running, your uptime counter keeps ticking. This is a fascinating way to confuse your monitoring systems (or your boss) if they rely on uptime to verify a reboot occurred. It technically is a reboot, just not the one they are used to.

Advanced Magic: Switching Roots
The feature gets wilder. You can use it to switch to a different root filesystem entirely.

If you populate /run/nextroot/ with a valid OS tree, systemd-soft-reboot will pivot into that directory and treat it as the new /.

```Bash
# Imagine you have a new OS snapshot mounted here
$ mount /dev/vdb1 /run/nextroot

# This reboots "into" the new disk, without dropping the kernel
$ systemctl soft-reboot
```

This is heavily used by "Image Based" Linux distros to apply updates seamlessly, effectively moving between A/B partitions without a cold boot.

Making Services Survive
You can actually configure services to survive this reboot. If you have a critical database or a job that absolutely cannot stop, you can tell systemd to leave it alone while everything else restarts around it.

Add this to your unit file:

```
[Unit]
Description=I Will Survive
DefaultDependencies=no
Conflicts=
Before=shutdown.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8000
SurviveFinalKillSignal=yes
This service will keep running (and holding its memory/file descriptors) while the rest of the world burns down and rebuilds.
```

Resources
If you want to dive deeper, here are the docs:

systemd-soft-reboot.service Man Page

Thorsten Kukuk: systemd soft-reboot and surviving it as application (OpenSUSE Conference 2024 talk)

TL;DR: If you don't need a new kernel, stop waiting for your BIOS.
