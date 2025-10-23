---
layout: post
title: "Automated files cleanup on Linux"
description: "🚮 Or: how I taught my Linux box to take out its own trash"
categories: [automation, sysadmin]
tags: [linux, systemd, opensuse, timers, sysadmin, cleanup]
author: Andrea Manzini
date: 2025-10-23

---

## 🧹 My Messy Linux Box 

As year passes, my Linux system, over the time, starts to get a little... *Messy*.

My `~/Downloads` directory is a digital dumping ground. It's a collection of ISOs, test scripts, and those huge multi-gigabyte Virtual Machine images I need to test once and then forget about. Add to that `~/Pictures/Screenshots`, which is overflowing with thousands of quick snaps I'll never look at again.

Disk space is cheap nowadays, but I like to have things nice and clean. I could go in and manually clean it... But who remembers to do that ?

So I setup a quick automated solution; a good occation to study **Systemd timers!**

My rule is simple: if I haven't accessed (or "opened") a file in either of those places for 30 days, I consider it junk and want it gone.

## 🗂️ Your Own Systemd Janitor

We just need to create two simple text files:

- A `.service` file: This tells the janitor what to do.
- A `.timer` file: This tells the janitor when to do it.

First, we need a place to put our new files. Systemd looks for user files in `~/.config/systemd/user/`.

```bash
mkdir -p ~/.config/systemd/user/
```

The first file will define the cleanup command.
Create a new file named `~/.config/systemd/user/cleanup-files.service`:

```ini
[Unit]
Description=Clean up old files in Download and Screenshots

[Service]
Type=oneshot
ExecStart=/usr/bin/find %h/Download %h/Pictures/Screenshots -type f -atime +29 -delete
Nice=19
IOSchedulingClass=idle
```

Let's break that down:

- `Type=oneshot`: This just means it runs a single command and stops.
- `ExecStart=...`: This is the magic command!
- `%h/Download %h/Pictures/Screenshots`: %h is systemd's special shortcut for your home directory. We tell find to look in both places.
- `-type f`: Only find files, not empty directories.
- `-atime +29`: Find files that were last accessed more than 29 days ago (i.e., 30 days or more).
- `-delete`: Yep. It deletes them.
- `Nice=19 & IOSchedulingClass=idle`: These are good manners. They tell the system to run this command with the lowest possible priority, so it never slows down your real work.

note: if your `/home/` filesystem is mounted with `noatime` or `relatime` options to improve performance, you might get more predictable results by using `mtime` (modification time) instead. This would delete files that haven't been changed in 30 days.

⚠️ Safety Warning! Before you let this run, do a dry run! Copy the command into your terminal, but remove the `-delete` part.

```bash
# THIS WILL ONLY LIST FILES. IT WILL NOT DELETE ANYTHING.
find ~/Download ~/Pictures/Screenshots -type f -atime +29
```

Now, let's make the schedule.

Create a new file named `~/.config/systemd/user/cleanup-files.timer`:

```ini
[Unit]
Description=Run cleanup-files.service daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

This one is simple:

- `OnCalendar=daily`: Run this once a day. (It usually runs around midnight).
- `Persistent=true`: This is the best part. If your computer was off at midnight, it will run the command as soon as you boot up and log in.`

## ⏲️ Start Your Timer!

You've built the janitor; Time to turn it on.
Tell systemd to read your new files:

```bash
systemctl --user daemon-reload
```

Enable and start the timer:

```bash
systemctl --user enable --now cleanup-files.timer
```

You can check that your timer is active and waiting by running:

```bash
systemctl --user status cleanup-files.timer
systemctl --user list-timers
```

## 🗑️ Bonus Step: Package Cleanup 

### (for openSUSE users)

File cleanup is great, but as a Tumbleweed user, My system gets constant updates, which can leave behind "unneeded" packages—dependencies that were installed for something but are no longer required. So I have also an handy alias

```bash
alias zclean='zypper packages --orphaned && zypper packages --unneeded'
```

that shows me potential candidate packages , which I can then remove with their dependencies :

```bash
zypper rm -u <PACKAGENAME>
```

Enjoy your cleaner system and Happy Hacking!

