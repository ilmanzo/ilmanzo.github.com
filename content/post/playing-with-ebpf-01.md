---
layout: post
title: "playing with eBPF interface -1"
description: "some fun experiments with tracing and snooping linux kernel"
categories: programming
tags: [python, C, linux, programming, learning, kernel, ebpf]
author: Andrea Manzini
date: 2021-05-11
---


[eBPF](https://ebpf.io/) is a revolutionary technology that can run sandboxed programs in the Linux kernel without changing kernel source code or loading kernel modules. Basically any user can write code for a virtual machine that can interact with the kernel data structure and functions.

[bcc](https://github.com/iovisor/bcc) is an high-level helper interface to eBPF (another is [bpftrace](https://github.com/iovisor/bpftrace)). To use it, start by [following installation guide](https://github.com/iovisor/bcc/blob/master/INSTALL.md) , but if you have a recent Debian system, it's just a matter of installing some packages:

    sudo apt install bpfcc-tools python3-bpfcc libbpfcc libbpfcc-dev


Now let's test our installation with the classical 'Hello, world' 

{{<highlight python >}}
#!/usr/bin/python3
# run with:
# sudo ./hello_world.py

import bcc

my_probe_src = r"""
int hello(void *ctx) {
  bpf_trace_printk("Hello world!\n");
  return 0;
}
"""

bpf = bcc.BPF(text=my_probe_src)
bpf.attach_kprobe(event=bpf.get_syscall_fnname("clone"), fn_name="hello")
bpf.trace_print()
{{</ highlight >}}

What does this program do ? It uses the [BCC framework](https://github.com/iovisor/bcc) to attach a simple "probe" to the linux kernel *sys_clone()* function, so each time the function is called, our hook gets executed. 
So when you run this simple program, you'll see on your terminal the message every time the syscall *clone()* function gets called. 

    b'           <...>-82733   [002] d... 11828.394029: bpf_trace_printk: Hello world!'
    b''
    b'           <...>-82225   [004] d... 11828.394071: bpf_trace_printk: Hello world!'
    b''
    b' DedicatedWorker-6802    [005] d... 11842.465428: bpf_trace_printk: Hello world!'
    b''
    b'           <...>-82723   [004] d... 11842.465491: bpf_trace_printk: Hello world!'
    b''
    b'           <...>-82956   [000] d... 11842.466093: bpf_trace_printk: Hello world!'
    b''
    b' ThreadPoolForeg-6590    [001] d... 11842.815580: bpf_trace_printk: Hello world!'


There is a lot to know about eBPF; What's the meaning of all the data displayed ? How to decode arguments ? How to obtain data values from probe ? What can we do in our function ? We have of course barely scratched the surface; we'll see in the next post!





