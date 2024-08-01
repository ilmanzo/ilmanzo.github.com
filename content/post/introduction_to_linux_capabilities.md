---
layout: post
description: "What are and how to use linux kernel capabilities"
title: "Playing with linux kernel capabilities"
categories: linux
tags: [linux, tutorial, system, kernel, security, sysadmin, access control]
author: Andrea Manzini
date: 2024-08-02
draft: true
---

## Intro

If you are an old-school sysadmin, you could be used to the "all-or-nothing" approach: if a shell or process is running with UID=0, it can do almost everything on a system; while a plain user process is restricted by some means: tipically it can't open RAW sockets, can't bind "privileged" ports under 1024, can't change a file ownership and so on. 
Linux capabilities is a feature, gradually introduced starting from kernel 2.2, that permits a more fine-grained control over privileged operations, breaking the traditional binary root/non-root distinction. Just as by using sudo we can run specific commands as another user (even root), without permanently becoming that user, by using capabilities, we can grant a process only certain privileges without having to run it as root.

## What 

The Linux kernel implements a multitude of these micro-grained permissions. Some of the most common capabilities used are:

- CAP_SYS_ADMIN: Allows a wide range of operations. This capability should be avoided in favor of more specific capabilities.
- CAP_CHOWN: Make changes to the User ID and Group ID of files 
- CAP_DAC_READ_SEARCH: Bypass file read, and directory read/execute checks. A program with this capability can be used to read any file on the system.
- CAP_DAC_OVERRIDE: Override DAC (Discretionary Access Control) i.e. bypass read/write/execute permission checks. This capability grants an executable the ability to access and modify any file on the filesystem.
- CAP_NET_BIND_SERVICE: Allows binding to port numbers lower than 1024.
- CAP_KILL: Bypass permission checks for sending signals to processes such as SIGHUP and SIGKILL.
- CAP_SYS_NICE: Modify the niceness value and scheduling priority of processes among others.
- CAP_SYS_RESOURCE: Allows overriding various limits on system resources, such as disk quotas, CPU time limits, etc.

At the time of writing, there are more than 40 capabilities defined and implementes; the full list is available in the `capabilities(7)` manual page. On the early years, only running processes could manipulate capabilities, while nowadays we can manage them directly on a binary file before it starts. 

There are two different packages for capability management: libcap and libcap-ng. The latter is designed to be easier than the former, so we will focus on that one. 

## setup

let's install the package we will use for our experiments: 

```
# zypper install libpcap-ng-utils 

# rpm -ql libcap-ng-utils 
/usr/bin/captest
/usr/bin/filecap
/usr/bin/netcap
/usr/bin/pscap
/usr/share/licenses/libcap-ng-utils
/usr/share/licenses/libcap-ng-utils/COPYING
/usr/share/man/man8/captest.8.gz
/usr/share/man/man8/filecap.8.gz
/usr/share/man/man8/netcap.8.gz
/usr/share/man/man8/pscap.8.gz
```

## A quick example

It's easy to launch a basic http server in Python:

```
/usr/bin/python3 -m http.server   
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
^C
Keyboard interrupt received, exiting.
```

by default it starts on port 8000, because unprivileged users can't bind lower port:

```
$ /usr/bin/python3 -m http.server 80
Traceback (most recent call last):
[...]
PermissionError: [Errno 13] Permission denied
```

it's sufficient to give the Python binary the capability to bind lower ports:

```
$ sudo filecap /usr/bin/python3 net_bind_service

$ /usr/bin/python3 -m http.server 80               
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
^C
Keyboard interrupt received, exiting.
```

to reset it back, we can use the `none` keyword:

```
$ sudo filecap /usr/bin/python3 none

$ /usr/bin/python3 -m http.server 80
[...]          
PermissionError: [Errno 13] Permission denied
```


##

On Linux kernel, capabilities are implemented as set of bits. There are five capability sets: Permitted, Inheritable, Effective, Bounding and Ambient. Of those, however, only the first three can be assigned to executable files. The Permitted capability set includes the capabilities assigned to a certain executable; the Effective set is a subset of the Permitted one and includes the capabilities which are effectively used. Finally, the Inheritable set, includes capabilities which can be inherited by child processes.