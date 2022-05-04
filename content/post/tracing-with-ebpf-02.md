---
layout: post
title: "playing with eBPF interface - 2"
description: "some fun experiments with tracing and snooping linux kernel"
categories: programming
tags: [python, C, linux, programming, learning, kernel, ebpf]
author: Andrea Manzini
date: 2021-05-19
---


In the [last post](http://ilmanzo.github.io/programming/2021/05/11/playing-with-ebpf) we introduced the [BCC framework](https://github.com/iovisor/bcc) to interface Python code with eBPF facility. Now we are ready to make one step further!


{{<highlight python >}}
#!/usr/bin/python3

import bcc

bpf = bcc.BPF(text="""
#include <uapi/linux/ptrace.h>
int trace_malloc(struct pt_regs *ctx, size_t size) {
    bpf_trace_printk("size=%d\\n",size);
    return 0;
};""")

bpf.attach_uprobe(name="c",sym="malloc",fn_name="trace_malloc")
while 1:
    (task, pid, cpu, flags, ts, msg) = bpf.trace_fields()
    print(f"task={task}\tmsg={msg}")
{{</ highlight >}}


This code is a little more complex, but still quite easy: first of all we use *bcc* to attach an "user space probe" instead of a kernel probe, and the function being observed will be libc's **malloc**. 

In the tracing code itself, we simply report the parameter given to malloc function to the outside world, so with an infinite loop we print the tracing messages. Just to make it more explicit, we extract all the fields one by one and print only two of them. 

It works like this: eBPF probe writes to a shared pipe named ```/sys/kernel/debug/tracing/trace_pipe``` , and python code reads from that pipe. The result is a fast scrolling stream of all the malloc invocations from all running programs, followed by the size requested.


| Field | Field |         |         
|Number | Name  | Meaning |
| ----  | ----- | -----   | 
| 0     | task  | The name of the application running when the probe fired  |
| 1     | pid   | process id (PID) of the application |
| 2     | cpu   | The CPU it was running on |
| 3     | flags | Various process context flags |
| 4     | ts    | A timestamp |
| 5     | msg   | The string that we passed to bpf_trace_printk() |

    task=b'Xorg'	msg=b'size=24'
    task=b'Xorg'	msg=b'size=24'
    task=b'gnome-terminal-'	msg=b'size=36'
    task=b'gnome-terminal-'	msg=b'size=16'
    task=b'Xorg'	msg=b'size=24'
    task=b'gnome-terminal-'	msg=b'size=24'
    task=b'gnome-terminal-'	msg=b'size=124'
    task=b'Xorg'	msg=b'size=24'
    task=b'gnome-terminal-'	msg=b'size=16'
    task=b'gnome-terminal-'	msg=b'size=312'
    task=b'Xorg'	msg=b'size=24'
    task=b'gnome-terminal-'	msg=b'size=72'

