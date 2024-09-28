---
layout: post
description: "Overview of the Linux kernel tracing feature"
title: "An overview of the Linux kernel tracing feature"
categories: linux
tags: [tutorial, linux, kernel, tracing, syscall, sysadmin]
author: Andrea Manzini
date: 2024-10-02
draft: true
---

## Intro

Tracing tools are pretty popular in the Unix/Linux ecosystem; for example we have [ltrace](https://man7.org/linux/man-pages/man1/ltrace.1.html) to trace library calls  in the user space programs and [strace](https://en.wikipedia.org/wiki/Strace) to dive in deeper and inspect syscall usage.  
One of the many features that Linux kernel offers is tracing every aspect of its execution at runtime.

## The basics

First of all, let be sure that the tracing virtual filesystem is mounted 

```bash
# mount | grep tracefs
tracefs on /sys/kernel/tracing type tracefs (rw,nosuid,nodev,noexec,relatime)
```

so we can inspect its handy user-level interface.

```bash
# cd /sys/kernel/tracing
# cat current_tracer 
nop
# cat README
tracing mini-HOWTO:

# echo 0 > tracing_on : quick way to disable tracing
# echo 1 > tracing_on : quick way to re-enable tracing

 Important files:
  trace                 - The static contents of the buffer
                          To clear the buffer write into this file: echo > trace
  trace_pipe            - A consuming read to see the contents of the buffer
  current_tracer        - function and latency tracers
  available_tracers     - list of configured tracers for current_tracer
  error_log     - error log for failed commands (that support it)
  buffer_size_kb        - view and modify size of per cpu buffer
  buffer_total_size_kb  - view total size of all cpu buffers
```

Lots of stuff ongoing here; there is even a cool README with some documentation but let's do it step by step.
the (virtual) file `current_tracer` contains `nop`, which means no tracer is enabled. We need to change it in order to trace something, and we have a long list of choices:

# cat available_tracers 
timerlat osnoise blk function_graph wakeup_dl wakeup_rt wakeup function nop

