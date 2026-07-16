---
layout: post
title: "SEGFAULT: Debugging a crashing application"
description: "What's a core dump and how to use it for debugging ?"
categories: linux
tags: [linux, sysadmin, opensuse, programming, debugging]
author: Andrea Manzini
date: 2024-04-05
---

## 🙀 Something breaks

If you use linux running some applications you could have seen sometimes a similar error message:

## `[1]    24975 segmentation fault (core dumped)`

what's meaning and how it can be useful ? Let's dig it out.

## 🧪 Lab Setup 

To make a proper case study, we need a crashing program. Of course they are very rare nowadays :grin: so we just create a new one ourself, showing off our worst C coding bad skills and practices.

Warning : this program is poorly written, just to show off how segmentation fault works, it's not intended for any other purpose... Dont' do that in a real context.
```c
// badprogram.c 
#include <stdio.h>
#include <string.h>

void makeitcrash() {
   char buffer[10000];
   memset(buffer, 0, sizeof(buffer));
   for(int i=1; i<100000; i*=2) buffer[i]='A'; // typo: a zero in excess
}

int main() {
   printf("Kaboom!");
   makeitcrash();
   return 0;
}
```

now we need to compile it, and we are also going to insert the debug symbols in the binary, so we'll use the `-g` flag:

```bash
$ gcc -g badprogram.c -o badprogram
./badprogram

[1]    7022 segmentation fault (core dumped)  ./badprogram
```

Good, it failed! But what really happened ? How and where it 'dumped' something ? :shit:

## 🐕 A bit of investigation 

There are [many resources out there](https://jvns.ca/blog/2018/04/28/debugging-a-segfault-on-linux/) that explain this stuff better than me, but long story short, when a program tries to access an invalid memory region (by any means, like dereferencing a `NULL` pointer for example), the operating system sends the *signal 11 (SIGSEGV)* error to the process. The default signal handler optionally creates a 'dump' file wich contains the memory of the process at the time of error and terminates it with an abrupt message.

Since they can take lots of space, usually by default core dumps are compressed; we can check some information about the dumped core with `coredumpctl` util:

```bash
$ coredumpctl info badprogram

           PID: 4269 (badprogram)
           UID: 1000 (andrea)
           GID: 1000 (andrea)
        Signal: 11 (SEGV)
     Timestamp: Fri 2024-04-05 11:13:45 CEST (6s ago)
  Command Line: ./badprogram
    Executable: /home/andrea/projects/coredumper/badprogram
          Unit: user@1000.service
     User Unit: vte-spawn-68d635ed-58e5-4522-95ee-2deb64da991a.scope
         Slice: user-1000.slice
     Owner UID: 1000 (andrea)
       Boot ID: [blablabla]
    Machine ID: [blablabla]
      Hostname: localhost
       Storage: /var/lib/systemd/coredump/core.badprogram.1000.9d49cca5818645e4baacc1ddddd7a9e8.4269.1712308425000000.zst (present)
  Size on Disk: 25.3K
       Message: Process 4269 (badprogram) of user 1000 dumped core.
                
                Stack trace of thread 4269:
                #0  0x0000000000401152 n/a (/home/andrea/projects/prove/coredumper/badprogram + 0x1152)
                #1  0x0000000000401175 n/a (/home/andrea/projects/prove/coredumper/badprogram + 0x1175)
                #2  0x00007f112f02a1f0 __libc_start_call_main (libc.so.6 + 0x2a1f0)
                #3  0x00007f112f02a2b9 __libc_start_main@@GLIBC_2.34 (libc.so.6 + 0x2a2b9)
                #4  0x0000000000401075 n/a (/home/andrea/projects/prove/coredumper/badprogram + 0x1075)
                ELF object binary architecture: AMD x86-64

```

side note: you can always get a dump from a running program by sending a `SIGABRT` signal to its process id, like:

`$ kill -ABRT $(pidof firefox-bin)`

## ⛏️ Going deeper 

Let's unpack that compressed file to an handy location and inspect it a bit :

```bash
$ zstd --uncompress /var/lib/systemd/coredump/core.badprogram.1000.9d49cca5818645e4baacc1ddddd7a9e8.4269.1712308425000000.zst -o badprogram.core
/var/lib/systemd/coredump/core.badprogram.1000.9d49cca5818645e4baacc1ddddd7a9e8.4269.1712308425000000.zst: 475136 bytes 
$ ls -l
-rwxr-xr-x 1 andrea andrea  21152 apr  5 11:08 badprogram*
-rw-r--r-- 1 andrea andrea    240 apr  5 09:30 badprogram.c
-rw-r----- 1 andrea andrea 475136 apr  5 11:13 badprogram.core
```
Now we run again the faulty program, only this time we do with the help of Gnu Debugger and passing also the coredump file:

```bash
$ gdb ./badprogram -c badprogram.core 

Program terminated with signal SIGSEGV, Segmentation fault.
#0  0x0000000000401188 in makeitcrash () at badprogram.c:7
7	   for(int i=1; i<100000; i*=2) buffer[i]='A';
(gdb) bt
#0  0x0000000000401188 in makeitcrash () at badprogram.c:7
#1  0x00000000004011bd in main () at badprogram.c:12
(gdb) print i
$1 = 32768
(gdb) 
$2 = 32768
(gdb) info locals
i = 32768
buffer = "\000AA\000A\000\000\000A\000\000\000\000\000\000\000A", '\000' <repeats 15 times>, "A", '\000' <repeats 31 times>, "A", '\000' <repeats 63 times>, "A", '\000' <repeats 127 times>...
```
thanks to the debug info included during the compilation, we are able to see the source of the offending code, and the variable value when the problem happened, giving us a starting point to remediate our mistake.

So at the end, what's the difference between having a coredump file or not ? Why can't we just re-run the same program and let it crash under GDB ?

`The point is to have in our hands the exact memory snapshot of the program at the time when it crashed.`

Maybe it's not feasible to run it now, or we don't have the same environment or cannot recreate the same conditions in our pc. But thanks to **core dumps** we are able to time-travel to that past. 

#### Extra tip : run gdb with the `-tui` option or type `tui enable` at the prompt to get a nice 'user-friendly' [interface](https://dev.to/irby/making-gdb-easier-the-tui-interface-15l2) :smile:

## 🚪 Closing toughts

Of course it won't be always so easy, but being able to inspect the memory process of a dead program is an invaluable debugging tool. One important observation is that often the packages we install don't have debug information attached, so we need to install them separately or build the source code by ourself. Even the kernel itself can be analyzed, by using [kernel crash core dumps](https://www.suse.com/support/kb/doc/?id=000016171). On Linux, even errors and crashes are nice and useful! 

As a follow up on GDB debugging, I recommend to read this excellent [blog post](https://www.brendangregg.com/blog/2016-08-09/gdb-example-ncurses.html) by Brendan Gregg.

