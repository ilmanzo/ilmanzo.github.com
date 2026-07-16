---
layout: post
title: "Fault Injection in Network Namespace and Veth Environments"
description: "How to improve your software by simulating a faulty network device"
categories: linux
tags: [linux, sysadmin, programming, testing, device, network, namespace]
author: Andrea Manzini
date: 2024-01-06
---

## Prelude

This is a followup from my [previous post](https://ilmanzo.github.io/post/faulty_disk_simulation/) and a sort of continuation on the series of the topic, where we are exploring ways to make our test system more "unreliable" in order to observe if our applications behave nicely under challenging and not-ideal environments.

In this article we are going to explore some linux technologies:
- Network Namespaces (**netns**)
- Virtual Ethernet Devices (**veth**)
- Network Emulation (**netem**) scheduling policy

The goal is to setup a virtual network link inside our system, make the two network devices talk each other and then simulate a *bad/slow/glitchy/flaky* communication to test how applications behave under difficult conditions.

Ready to play and break something ?

![broken network](/img/pexels-broken-net-14839933.jpeg)
Image credits: [Abdulvahap Demir](https://www.pexels.com/@infovahapdmr/)


## Setup netns

Network namespaces represent a core technology essential for containers, enabling the establishment of segregated network environments within a Linux system. They facilitate the creation of distinct network stacks for processes, including interfaces, routing tables, and firewall rules. This segregation guarantees that processes within one network namespace remain separate and insulated from those in other namespaces.

to create and manage `netns` we just need the `ip` command:

```bash
$ ip netns add ns_1
$ ip netns add ns_2
```
With this commands we just configured an empty space, now we need to place something inside.

## Setup virtual ethernet

Veth devices, abbreviated from virtual Ethernet devices, are dual virtual network interfaces employed to link network namespaces. Each pair comprises two endpoints: one within a specific namespace and the other in a separate namespace. These virtual interfaces mimic Ethernet cables, enabling seamless communication between the interconnected namespaces. Traffic can traverse this veth pair bidirectionally, facilitating two-way transmission.

```bash
$ ip link add veth_1 type veth peer name veth_2
$ ip link set veth_1 netns ns_1
$ ip link set veth_2 netns ns_2
$ ip netns exec ns_1 ip link set dev veth_1 up
$ ip netns exec ns_2 ip link set dev veth_2 up
```

note: `ip netns ns_1 exec COMMAND` is an handy shorthand for executing a single command in a specific namespace.

Inside your machine, there now will be *two* new **independent** namespaces, each with its own virtual network card, totally separate from the *host* environment:

```
          ┌──────────────────────────────────────────────────────────┐
          │ Linux machine                                            │
          │                                                          │
          │       ┌──────────────┐            ┌──────────────┐       │
          │       │     ns_1     │            │     ns_2     │       │
          │       │              │            │              │       │
          │       │              │            │              │       │
          │       │              │            │              │       │
          │       │              │            │              │       │
          │       │    ┌─────────┤            ├─────────┐    │       │
          │       │    │         │◄───────────┤         │    │       │
          │       │    │  veth_1 │            │ veth_2  │    │       │
          │       │    │         ├───────────►│         │    │       │
          │       │    └─────────┤            ├─────────┘    │       │
          │       │              │            │              │       │
          │       └──────────────┘            └──────────────┘       │
          │                                                          │
          │                                                          │
          └──────────────────────────────────────────────────────────┘
```

## Addressing

So far your virtual devices does not yet have any IP address, even loopback is down:

```bash 
$ ip -all netns exec ip link show

netns: ns_1
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
9: veth_1@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 52:69:cf:de:7d:10 brd ff:ff:ff:ff:ff:ff link-netns ns_2

netns: ns_2
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
8: veth_2@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 6e:19:3c:20:e0:9a brd ff:ff:ff:ff:ff:ff link-netns ns_1
```

let's give them a random IPV4 on the same subnet:

```bash
$ ip netns exec ns_1 ip addr add 10.1.1.1/24 dev veth_1 
$ ip netns exec ns_2 ip addr add 10.1.1.2/24 dev veth_2
```

The cool thing now is that we can reach the other end only via namespace. Just to be clear, this is not going to work:

```bash
$ ping -c 3 10.1.1.2 
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.

--- 10.1.1.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2020ms
```

Why ? Because we need to run `ping` command from the proper namespace:

```bash
$ ip netns exec ns_1 ping -c 3 10.1.1.2
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.
64 bytes from 10.1.1.2: icmp_seq=1 ttl=64 time=0.040 ms
64 bytes from 10.1.1.2: icmp_seq=2 ttl=64 time=0.044 ms
64 bytes from 10.1.1.2: icmp_seq=3 ttl=64 time=0.057 ms

--- 10.1.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2021ms
rtt min/avg/max/mdev = 0.040/0.047/0.057/0.007 ms
```

Looking at those rtt numbers, this virtual network seems working fast and smooth, so it's time to break something... 😈

## Fault injection

Let's add a 50ms ± 25ms random delay to each packet on one side:  

```bash
$ ip netns exec ns_1 tc qdisc add dev veth_1 root netem delay 50ms 25ms
```
on the other side, we also simulate a 50% chance of a dropped packed, with a 25% chance of subsequent packet loss (to emulate packet burst losses)

```bash 
$ ip netns exec ns_2 tc qdisc add dev veth_2 root netem loss 50% 25%
```

How the ping will do ? Pretty *bad* indeed: 👎

```bash
$ ip netns exec ns_1 ping -c 10 10.1.1.2
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.
64 bytes from 10.1.1.2: icmp_seq=1 ttl=64 time=66.6 ms
64 bytes from 10.1.1.2: icmp_seq=3 ttl=64 time=34.6 ms
64 bytes from 10.1.1.2: icmp_seq=4 ttl=64 time=41.6 ms
64 bytes from 10.1.1.2: icmp_seq=6 ttl=64 time=28.0 ms
64 bytes from 10.1.1.2: icmp_seq=9 ttl=64 time=51.6 ms
64 bytes from 10.1.1.2: icmp_seq=10 ttl=64 time=50.8 ms

--- 10.1.1.2 ping statistics ---
10 packets transmitted, 6 received, 40% packet loss, time 9081ms
rtt min/avg/max/mdev = 28.031/45.522/66.569/12.561 ms
```

Another couple cool features of `netem` are **Packet corruption**, which simulates a single bit error at a random offset in the packet, and **Packet Re-ordering**, which causes a certain percentage of the packets to arrive in a wrong order. For any detail, you can consult the `tc-netem(8)` [man page](https://man7.org/linux/man-pages/man8/tc-netem.8.html).

## Wrap and clean up

We ended with a simulated network where we can control packet loss and delay / jitter , we can do any experiment we need by running our services in the proper namespace. 

When we are finished, if we don't have any other namespace defined, it's simple to remove every track from our system with a single command:

```bash
$ ip --all netns del
```
