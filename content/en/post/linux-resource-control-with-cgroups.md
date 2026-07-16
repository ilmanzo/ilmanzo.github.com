---
layout: post
title: "linux resource control with cgroups"
description: "using systemd slices to manage resources"
categories: linux
tags: [linux, systemd, performance, monitoring]
author: Andrea Manzini
date: 2022-05-03
---


## intro

Resource isolation is an hot topic these days, and it's a problem excellently solved by containerization. However, we can achieve isolation between internal tasks of an operating system by leveraging a technology exposed by the kernel: cgroups. This component is also used by Docker, and other Linux container technologies.

Cgroups are the Linux way of organizing groups of processes: roughly speaking a cgroup is to a process what a process is to a thread: one can have many threads belonging to the same process, and in the same way one can join many processes inside the same cgroup.


## the problem

Suppose we have an already busy server, maybe a database; and we want to run on the same machine a periodical job which is short but quite intensive. Of course we don't want an huge impact on the service performance. Let's say our cpu-bound process is represented by this script:

{{< highlight bash >}}
#!/bin/bash
#dosomework.sh
{ 
  sleep 30
  kill $$
} &
while true; do true; done 
{{</ highlight >}}

we can define a **slice** to control the resource sharing of our services and model the relative weight that the system should assign:

{{< highlight bash >}}
#mydatabase-extrajob.slice
[Unit]
Description=Slice used to run companion programs. Memory, CPU and IO restricted
Before=slices.target

[Slice]
MemoryAccounting=true
IOAccounting=true
CPUAccounting=true

CPUWeight=10
IOWeight=10

MemoryHigh=4%
MemoryLimit=5%
CPUShares=10
BlockIOWeight=10
{{</ highlight >}}


while the db service will have another resource definition:

{{< highlight bash >}}
#mydatabase-server.slice
[Unit]
Description=Slice used to run DB. Maximum priority for IO and CPU
Before=slices.target

[Slice]
MemoryAccounting=true
IOAccounting=true
CPUAccounting=true
MemorySwapMax=1
CPUShares=1000
CPUWeight=1000
{{</ highlight >}}

and we need to apply this slice to the .service  

{{< highlight bash >}}
[Service]
...
Slice=mydatabase-server.slice
{{</ highlight >}}


By saying that the DB service has weight=1000 and the other program has weight=10, we tell the operating system that DB is 100 times more important when any CPU contention occurs.


## ad hoc commands
Systemd slices are a powerful way to protect services that are managed by systemd from each other. But what if I just want to run some command, and am too worried that it may use up precious resources from the main service?

Thankfully, systemd provides a way to run ad-hoc commands inside an existing slice. So the cautious admin can use that too:

{{< highlight bash >}}
sudo systemd-run --uid=$(id -u dbuser) --gid=$(id -g dbgroup) -t --slice=mydatabase-extrajob.slice /path/to/my/tool
{{</ highlight >}}


## Conclusion
Systemd slices exposes the cgroups interface — which underpins the isolation infrastructure used by Docker and other Linux container technologies — in an elegant and powerful way. Services managed by Systemd, like databases, can use this infrastructure to isolate their main components from other auxiliary helper tools that may use too much resources. For other reference, [SystemD documentation](https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html#) is quite extensive.


## credits

Glauber Costa's [Isolating workloads with Systemd slices](https://www.scylladb.com/2019/09/25/isolating-workloads-with-systemd-slices/)
