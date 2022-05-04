---
layout: post
title: "number of physical sockets and cpu cores"
description: "how to find out how much your next licence will cost..."
categories: sysadmin
tags: [linux, hardware, cpu, scripting, system information]
author: Andrea Manzini
date: 2013-09-14
---

a small script to check out the number of processors in your linux machine

<pre>
#!/bin/bash
S=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
C=$(grep "cpu cores" /proc/cpuinfo |sort -u |cut -d":" -f2)

grep -i "model name" /proc/cpuinfo
echo your system has $S sockets with $C CPU cores each
</pre>

mandatory sample output:

<pre>
model name      : Intel(R) Xeon(R) CPU           L5640  @ 2.27GHz
your system has 2 sockets with 6 CPU cores each
</pre>
