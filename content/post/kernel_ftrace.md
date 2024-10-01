---
layout: post
description: "Overview of the Linux kernel tracing feature"
title: "The Linux kernel ftrace"
categories: linux
tags: [tutorial, linux, kernel, tracing, syscall, sysadmin, debug]
author: Andrea Manzini
date: 2024-10-01
---

## 👣 Intro

Tracing tools are pretty popular in the Unix/Linux ecosystem; for example in the userspace we have [ltrace](https://man7.org/linux/man-pages/man1/ltrace.1.html) to trace library calls of the programs and [strace](https://en.wikipedia.org/wiki/Strace) to dive in deeper and inspect syscall usage. 

One of the many features that Linux kernel offers since 2008 (then evolved) is [ftrace](https://www.kernel.org/doc/html/latest/trace/ftrace.html) that allows many different kind of tracing at runtime. While not as flexible as [eBPF](https://ebpf.io/) technology, it can be helpful in some occasion and doesn't require a full fledged programming language.

![traces](/img/pexels-karolina-grabowska-6633887.jpg)
[Photo by Karolina Kaboompics](https://www.pexels.com/photo/close-up-of-sidewalk-covered-in-snow-6633887/)

## 🐤 The basics

First of all, let's be sure that your kernel is compiled with the option CONFIG_FTRACE and the tracing virtual filesystem is mounted:

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

Lots of stuff ongoing here; we have even a cool *README* with some documentation but let's do it step by step.
the (virtual) file `current_tracer` contains `nop`, which means no tracer is enabled. We need to change it in order to trace something, and we have a long list of choices:

## 🤔 What can I do ?

```bash
# cat /sys/kernel/tracing/available_tracers 
timerlat osnoise blk function_graph wakeup_dl wakeup_rt wakeup function nop
```

- function tracers: `function`, `function_graph`
- latency tracers: `wakeup_dl`, `wakeup_rt`, `irqsoff`, `wakeup`, `timerlat` 
- I/O tracers: `blk`
- IRQ/NMI: `osnoise`, `hwlat` 

To enable a tracer, we just have to write its name to current_tracer:

```bash
# echo function > current_tracer
```

At this point you can turn on tracing with `echo 1 > tracing_on` and start reading from the `trace` virtual file (which contains the content of the trace buffer) or `trace_pipe` (which streams tracing datapoints while we read them).

## 🔧 A better tool

If dealing with filesystem may be a bit cumbersome, there is an handy command-line tool created by [Steven Rostedt](https://github.com/rostedt) and called `trace-cmd`:

```bash
$ sudo zypper in trace-cmd
Loading repository data...
Reading installed packages...
Resolving package dependencies...

The following 3 NEW packages are going to be installed:
  libtraceevent1 libtracefs1 trace-cmd

3 new packages to install.
```

Let's see some usage examples:

```bash
# trace-cmd start -p function
```

starts tracing with the `function` tracer (displays function calls); once started, you can see the data with 

```bash
# trace-cmd show
```

```
# tracer: function
#
# entries-in-buffer/entries-written: 51265/8953395   #P:1
#
#                                _-----=> irqs-off/BH-disabled
#                               / _----=> need-resched
#                              | / _---=> hardirq/softirq
#                              || / _--=> preempt-depth
#                              ||| / _-=> migrate-disable
#                              |||| /     delay
#           TASK-PID     CPU#  |||||  TIMESTAMP  FUNCTION
#              | |         |   |||||     |         |
    sshd-session-3242    [000] d..3.  5838.785487: finish_task_switch.isra.0 <-__schedule
    sshd-session-3242    [000] d..3.  5838.785488: _raw_spin_unlock <-finish_task_switch.isra.0
    sshd-session-3242    [000] ...1.  5838.785489: __fdget <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785490: sock_poll <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785490: tcp_poll <-sock_poll
    sshd-session-3242    [000] ...1.  5838.785491: tcp_stream_memory_free <-tcp_poll
    sshd-session-3242    [000] ...1.  5838.785492: __fdget <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785492: sock_poll <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785493: tcp_poll <-sock_poll
    sshd-session-3242    [000] ...1.  5838.785493: tcp_stream_memory_free <-tcp_poll
    sshd-session-3242    [000] ...1.  5838.785494: __fdget <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785495: tty_poll <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785495: tty_ldisc_ref_wait <-tty_poll
    sshd-session-3242    [000] ...1.  5838.785496: ldsem_down_read <-tty_ldisc_ref_wait
    sshd-session-3242    [000] ...1.  5838.785496: __cond_resched <-ldsem_down_read
    sshd-session-3242    [000] ...1.  5838.785497: n_tty_poll <-tty_poll
    sshd-session-3242    [000] ...1.  5838.785500: tty_buffer_flush_work <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785500: flush_work <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785501: __cond_resched <-flush_work
    sshd-session-3242    [000] ...1.  5838.785501: __flush_work <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785502: __rcu_read_lock <-__flush_work
    sshd-session-3242    [000] ...1.  5838.785502: _raw_spin_lock_irq <-__flush_work
    sshd-session-3242    [000] d..2.  5838.785505: _raw_spin_unlock_irq <-__flush_work
    sshd-session-3242    [000] ...1.  5838.785506: __rcu_read_unlock <-__flush_work
    sshd-session-3242    [000] ...1.  5838.785506: tty_hung_up_p <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785507: mutex_is_locked <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785507: tty_chars_in_buffer <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785508: tty_write_room <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785508: pty_write_room <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785509: tty_buffer_space_avail <-n_tty_poll
```

And stop with `# trace-cmd stop` ; you can also clear the buffer with `# trace-cmd clear -a` or perform both tasks with a simple `# trace-cmd reset`.

An example with a different tracer :

```bash
# trace-cmd start -p function_graph --max-graph-depth 5
```

Starts tracing all the called function (up to 5 levels deep). Beware it may produce an huge amount of data:

```bash
# trace-cmd show
```

```
# tracer: function_graph
#
# CPU  DURATION                  FUNCTION CALLS
# |     |   |                     |   |   |   |

 ------------------------------------------
 0)  sshd-se-3242  =>  kworker-3680 
 ------------------------------------------

 0)               |        finish_task_switch.isra.0() {
 0)   0.621 us    |          _raw_spin_unlock();
 0)   1.884 us    |        }
 0) ! 200.114 us  |      } /* __cond_resched */
 0)   0.601 us    |      mutex_unlock();
 0) ! 225.651 us  |    } /* flush_to_ldisc */
 0)   0.591 us    |    __cond_resched();
 0)   0.592 us    |    _raw_spin_lock_irq();
 0)   0.630 us    |    pwq_dec_nr_in_flight();
 0) ! 233.837 us  |  } /* process_one_work */
 0)               |  process_one_work() {
 0)   0.591 us    |    kick_pool();
 0)   0.591 us    |    set_work_pool_and_clear_pending();
 0)   0.591 us    |    _raw_spin_unlock_irq();
 0)               |    wq_barrier_func() {
 0)               |      complete() {
 0)   0.601 us    |        _raw_spin_lock_irqsave();
 0)               |        try_to_wake_up() {
 0)   0.591 us    |          _raw_spin_lock_irqsave();
 0)   0.611 us    |          ttwu_queue_wakelist();
 0)   0.861 us    |          raw_spin_rq_lock_nested();
 0)   0.711 us    |          update_rq_clock();
 0)   6.762 us    |          ttwu_do_activate();
 0)   0.591 us    |          _raw_spin_unlock();
 0)   0.611 us    |          _raw_spin_unlock_irqrestore();
 0) + 15.138 us   |        }
 0)   0.611 us    |        _raw_spin_unlock_irqrestore();
 0) + 18.515 us   |      }
 0) + 19.627 us   |    }
 0)   0.601 us    |    __cond_resched();
 0)   0.601 us    |    _raw_spin_lock_irq();
 0)   0.601 us    |    pwq_dec_nr_in_flight();
 0) + 27.621 us   |  }
 0)   0.622 us    |  worker_enter_idle();
 0)   0.592 us    |  _raw_spin_unlock_irq();
 0)               |  schedule() {
 0)               |    wq_worker_sleeping() {
 0)   0.611 us    |      kthread_data();
 0)   1.763 us    |    }
 0)   0.621 us    |    rcu_note_context_switch();
 0)               |    raw_spin_rq_lock_nested() {
 0)   0.590 us    |      _raw_spin_lock();
 0)   1.694 us    |    }
 0)   0.712 us    |    update_rq_clock();
 0)               |    dequeue_task() {
```

Will display a nice view of the nested function calls that happens in the kernel, with the timing in microseconds on the side.

## 📼 Recording and filtering 

This tool can also work by "recording" in a data file all the collected trace point, then we can use the same utility or also [other](https://kernelshark.org/) to inspect the data.
This is specially useful for rare events or if you need to debug special issues that seems to occur randomly.

```bash
# trace-cmd record
```

will start tracing and writing the data to a file (named by default `trace.dat`). After stopping the trace, you can then display the data with

```bash
# trace-cmd report
```

A filter on the `irq_handler` event and function `do_IRQ` will display how long the IRQ takes in the kernel:

```bash
# trace-cmd record -p function_graph -l do_IRQ -e irq_handler_entry sleep 10
# trace-cmd report | grep irq_handler_entry -A 2


           sleep-4253  [000]  7340.590340: irq_handler_entry:    irq=27 name=virtio2-input.0
           sleep-4253  [000]  7340.590340: funcgraph_entry:        4.438 us   |          vring_interrupt();
           sleep-4253  [000]  7340.590345: funcgraph_exit:         6.201 us   |        }
--
           sleep-4253  [000]  7340.590767: irq_handler_entry:    irq=28 name=virtio2-output.0
           sleep-4253  [000]  7340.590769: funcgraph_exit:         3.136 us   |          }
           sleep-4253  [000]  7340.590769: funcgraph_entry:        0.270 us   |          _raw_spin_unlock();
--
          <idle>-0     [000]  7340.610004: irq_handler_entry:    irq=27 name=virtio2-input.0
          <idle>-0     [000]  7340.610011: funcgraph_exit:         8.436 us   |          }
          <idle>-0     [000]  7340.610011: funcgraph_entry:        1.031 us   |          add_interrupt_randomness();
--
    sshd-session-3242  [000]  7340.610566: irq_handler_entry:    irq=28 name=virtio2-output.0
    sshd-session-3242  [000]  7340.610571: funcgraph_exit:         8.456 us   |          }
    sshd-session-3242  [000]  7340.610572: funcgraph_entry:      + 11.051 us  |          irq_exit_rcu();
```

To display all the (kernel) memory operations allocation smaller than 512 bytes, we can filter on `kmalloc` event and a specific field:

```bash
# trace-cmd record -e kmem:kmalloc -f 'bytes_req < 512'

    sshd-session-3242  [000]  8115.304880: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d300 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.325365: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.344938: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.364728: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.385613: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.405250: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.426718: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
```

To get all available functions/events/tracers and so on you can use the `list` [options](https://www.man7.org/linux/man-pages/man1/trace-cmd-list.1.html).

```bash
# trace-cmd list -h

trace-cmd version 3.2.0 (3.2.0)

usage:
 trace-cmd list [-e [regex]][-t][-o][-f [regex]]
          -e list available events
            -F show event format
            --full show the print fmt with -F
            -R show event triggers
            -l show event filters
          -t list available tracers
          -o list available options
          -f [regex] list available functions to filter on
          -P list loaded plugin files (by path)
          -O list plugin options
          -B list defined buffer instances
          -C list the defined clocks (and active one)
          -c list the supported trace file compression algorithms
```

## 🎩 Some tricks and tips

Instead of analyzing the whole system, you may want to trace kernel activities only relative to a specific process (PID); with the `-P` option:

```bash
# trace-cmd record -p function -P 174
```

on system with very low disk space (like embedded boards), you cannot easily store big trace files to be analyzed later. `trace-cmd` can send the trace remotely over a network. Just start it on the host with the *listen port* option:

```bash
# trace-cmd listen -p 12345 -D 
```

and then on the device you can "save" events and data to the remote peer: 

```bash
# trace-cmd record -N mypc.local.net:12345 [tracing options]
``` 

A trick for module developers : trace only some specific kernel mod by searching for functions that ends with `]` (partial output):

```bash
# lsmod | grep thinkpad
thinkpad_acpi         196608  0
platform_profile       12288  1 thinkpad_acpi
sparse_keymap          12288  1 thinkpad_acpi
rfkill                 40960  9 bluetooth,thinkpad_acpi,cfg80211
snd                   159744  57 snd_ctl_led,snd_hda_codec_generic,snd_seq,snd_seq_device,snd_hda_codec_hdmi,snd_hwdep,snd_hda_intel,snd_usb_audio,snd_usbmidi_lib,snd_hda_codec,snd_hda_codec_realtek,snd_sof,snd_timer,snd_compress,thinkpad_acpi,snd_soc_core,snd_ump,snd_pcm,snd_rawmidi
video                  81920  2 thinkpad_acpi,amdgpu
battery                28672  1 thinkpad_acpi

# trace-cmd list -f  | grep 'thinkpad_acpi]$ | grep bluetooh'
bluetooth_attr_is_visible [thinkpad_acpi]
bluetooth_set_status [thinkpad_acpi]
bluetooth_get_status [thinkpad_acpi]
bluetooth_exit [thinkpad_acpi]
bluetooth_shutdown [thinkpad_acpi]
bluetooth_enable_store [thinkpad_acpi]
bluetooth_enable_show [thinkpad_acpi]
bluetooth_write [thinkpad_acpi]
bluetooth_read [thinkpad_acpi]
```

and see what useful functions we can put under our trace, or check how our newly developed module is behaving. 

## 🏄‍♂️ Outro and references:

If you are into kernel development or just curious about how Linux internals work, you can rely on this useful feature to get interesting insights of your system. 
I'll leave here some other websites and blog post that talks about ftrace:
- [the official Kernel documentation](https://www.kernel.org/doc/html/latest/trace/ftrace.html)
- A nice [Blog Post](https://sergioprado.blog/tracing-the-linux-kernel-with-ftrace/) from Sergio Prado 
- Two posts on opensource.com from Gaurav Kamathe: [1](https://opensource.com/article/21/7/linux-kernel-ftrace) and [2](https://opensource.com/article/21/7/linux-kernel-trace-cmd)
- An (old but gold) [LWN article](https://lwn.net/Articles/410200/)

If you are interested in the topic as I am, feel free to drop me any comment or feedback and I will be happy to have a follow up 😉

Thanks for reading and Happy hacking! 


