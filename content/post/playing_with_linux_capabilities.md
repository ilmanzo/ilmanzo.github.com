---
layout: post
description: "What are and how to use the Linux kernel capabilities"
title: "Playing with Linux kernel capabilities"
categories: linux
tags: [linux, tutorial, system, kernel, security, sysadmin, capabilities]
author: Andrea Manzini
date: 2024-08-02
---

## 🔐 Intro

As an experienced sysadmin, you might be familiar with the traditional "all-or-nothing" approach: if a shell or process is running with `UID==0`, it can do almost everything on a system; while a plain user process is restricted by some means: tipically it can't open RAW sockets, can't bind "privileged" ports under 1024, can't change a file ownership and so on.

Linux capabilities is a feature, gradually introduced starting from kernel 2.2, that permits a more fine-grained control over privileged operations, breaking the traditional binary root/non-root distinction. Just as by using sudo we can run specific commands as another user (even root), without permanently becoming that user, by using capabilities, **we can grant a program only certain privileges without having to run it as root**.

![linux-on-ice](/img/pexels-realtoughcandy-11034131.jpg)
Image credits to: [@realtoughcandy](https://www.pexels.com/@realtoughcandy/)

## 🧩 What ?

The idea is simple: just split all the possible privileged kernel calls up into groups of related functionality, then we can assign processes only to the subset they need. So the kernel calls were split up into a few dozen different categories, largely successfully.

The Linux kernel implements a multitude of these micro-grained permissions. Some of the most common capabilities used are:

- CAP_SYS_ADMIN: Allows a wide range of operations. This capability should be avoided in favor of more specific capabilities.
- CAP_CHOWN: Make changes to the User ID and Group ID of files 
- CAP_DAC_READ_SEARCH: Bypass file read, and directory read/execute checks. A program with this capability can be used to read any file on the system.
- CAP_DAC_OVERRIDE: Override DAC (Discretionary Access Control) i.e. bypass read/write/execute permission checks. This capability grants an executable the ability to access and modify any file on the filesystem.
- CAP_NET_BIND_SERVICE: Allows binding to port numbers lower than 1024.
- CAP_KILL: Bypass permission checks for sending signals to processes such as SIGHUP and SIGKILL.
- CAP_SYS_NICE: Modify the niceness value and scheduling priority of processes among others.
- CAP_SYS_RESOURCE: Allows overriding various limits on system resources, such as disk quotas, CPU time limits, etc.

The capabilities feature was introduced in 2.2 kernel in the year 1999, but it was only scoped to processes. In 2008, capabilities were introduced for files too.
At the time of writing, there are 40 capabilities defined and implements; you can get the full list with the command

```bash
$ systemd-analyze capability
```

or in the [`capabilities(7)`](https://man7.org/Linux/man-pages/man7/capabilities.7.html) manual page.   

## 🔧 How ?

Talking about user space, there are two different packages for capability management: `libcap` and `libcap-ng`. The latter is designed to be easier than the former, so we will focus on that one. 

Let's install the package we will use for our experiments: 

```bash
$ sudo zypper install libpcap-ng-utils 

$ rpm -ql libcap-ng-utils 
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

The package provides several useful tools:

- `captest`: Tests the capabilities of the current process
- `filecap`: Views or changes file capabilities
- `netcap`: Shows the network capabilities of network-facing programs
- `pscap`: Lists the capabilities of running processes


Using filecap:
`filecap` is used to view or change file capabilities. Here's how to use it:

## 💻 A quick example

It's easy to launch a basic http server in Python:

```bash
/usr/bin/python3 -m http.server   
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
^C
Keyboard interrupt received, exiting.
```

by default it starts on port 8000, because unprivileged users can't bind lower port:

```bash
$ /usr/bin/python3 -m http.server 80
Traceback (most recent call last):
[...]
PermissionError: [Errno 13] Permission denied
```

We can grant the Python binary the capability to bind to lower ports by using:

```bash
$ sudo filecap /usr/bin/python3 net_bind_service

$ /usr/bin/python3 -m http.server 80               
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
^C
Keyboard interrupt received, exiting.
```

to reset it back, we can use the `none` keyword:

```bash
$ sudo filecap /usr/bin/python3 none

$ /usr/bin/python3 -m http.server 80
[...]          
PermissionError: [Errno 13] Permission denied
```

## ⚙️ Using systemd

Systemd, the init system used in many modern Linux distributions, provides robust support for managing capabilities. 
This integration allows for fine-grained control over service privileges without resorting to running services as root.

Capability-related Directives:
Systemd unit files support several directives for managing capabilities:


- `CapabilityBoundingSet`: Limits the capabilities a service can have.
- `AmbientCapabilities`: Grants additional capabilities to a service.
- `SecureBits`: Sets secure bits flags to further restrict capability usage.

Here's an example of a systemd unit service file that grants permission to bind to lower ports:

```
[Service]
User=bob
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

## 🔍 A look inside

On Linux kernel, Conceptually capabilities are maintained in sets, which are represented as bit masks. For all running processes capability information is maintained per thread; for binaries in the file system it’s stored in extended attributes. 
There are five capability sets: *Permitted*, *Inheritable*, *Effective*, *Bounding* and *Ambient*. Of those, however, only the first three can be assigned to executable files. The *Permitted* capability set includes the capabilities assigned to a certain executable; the *Effective* set is a subset of the Permitted one and includes the capabilities which are effectively used. Finally, the *Inheritable* set, includes capabilities which can be inherited by child processes. For a detailed explanation of capabilities flow paths, please check [this blog post](https://blog.ploetzli.ch/2014/understanding-Linux-capabilities/) from Henryk Plötz or [this one](https://blog.container-solutions.com/Linux-capabilities-why-they-exist-and-how-they-work) from Adrian Mouat.


For running processes, you can easily get the bit mask looking at the `/proc/$PID/status`:

```bash
$ grep Cap "/proc/$(pidof chronyd)/status"
CapInh:	0000000000000000
CapPrm:	0000000002000400
CapEff:	0000000002000400
CapBnd:	000001c08380fddf
CapAmb:	0000000000000000
```

And it's easier to read when decoded:

```bash
$ pscap -p $(pidof chronyd)
ppid  pid   uid         command             capabilities
1     1803  chrony      chronyd             net_bind_service, sys_time +
```

or with the help of `capsh` (from package  `libcap-progs`):

```bash
$ capsh --decode=000001c08380fddf 
0x000001c08380fddf=cap_chown,cap_dac_override,cap_dac_read_search,cap_fowner,cap_fsetid,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_broadcast,cap_net_admin,cap_net_raw,cap_ipc_lock,cap_ipc_owner,cap_sys_nice,cap_sys_resource,cap_sys_time,cap_setfcap,cap_perfmon,cap_bpf,cap_checkpoint_restore
```

## 🎯 Why should I care ?

Capabilities offer a way to reduce a system's attack surface by granting each service only the minimum level of privileges it needs, thus avoiding the need to run services as the root user.

In the era of microservices, containers and kubernetes, capabilities plays an important role for a number of reasons:

- *Fine-grained security control*:
Capabilities allow for a more granular approach to granting privileges to processes, as opposed to the traditional all-or-nothing root access. This enables containers to run with only the specific privileges they need, improving overall system security.

- *Principle of least privilege*:
By assigning only necessary capabilities to containers, administrators can enforce the principle of least privilege. This reduces the potential attack surface and limits the damage that could be caused if a container is compromised.

- *Compatibility with non-root containers*:
Many organizations prefer to run containers as non-root users for security reasons. Capabilities allow these non-root containers to perform specific privileged operations without requiring full root access.

- *Kubernetes Pod Security Policies*:
In Kubernetes, Pod Security Policies can leverage Linux capabilities to define a set of conditions that a pod must meet to be accepted into the system. This allows cluster administrators to enforce security best practices across the entire cluster. By using `SecurityContext` in Kubernetes manifest, you can set the capabilities in containers. 

- *Container isolation*:
Capabilities help maintain strong isolation between containers and the host system, as well as between different containers, by limiting what each container can do.

- *Compliance requirements*:
Many security standards and compliance frameworks require the principle of least privilege. Using capabilities helps organizations meet these requirements while still allowing containers to function as needed.

- *Flexibility in container design*:
Developers can design containers that require specific privileged operations without needing to run the entire container as root, leading to more secure and flexible application designs.

## 🔗 Further Readings

- [Docker security documentation on Linux capabilities](https://docs.docker.com/engine/security/security/#linux-kernel-capabilities)
- [Systemd documentation on execution environment](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
- [libcap-ng project page](https://people.redhat.com/sgrubb/libcap-ng/)

## 🏁 Outro

Linux capabilities represent a powerful and flexible approach to security. By breaking down the traditional all-or-nothing root privileges into finer-grained permissions, capabilities enable system administrators and developers to implement the principle of least privilege effectively.

