---
layout: post
title: "Playing with Rust on ARM architecture"
description: "Easy cross compilation for everyone"
categories: programming
tags: [rust, device, programming, arm]
author: Andrea Manzini
date: 2024-03-01
---

### An old find

I found an old [cubieboard3 (cubietruck)](http://cubieboard.org/tag/cubietruck/) collecting dust in a drawer, so I took the chance to try out Rust cross compilation and collect here some notes about the process. Here's the baby:

![cubietruck](/img/cubietruck.jpg)

### Give it a penguin 

First of all, I installed an ARM linux distro on a MicroSD card and started the device:

```bash
[user@arm ~]$ cat /proc/cpuinfo 
processor	: 0
model name	: ARMv7 Processor rev 4 (v7l)
BogoMIPS	: 50.52
Features	: half thumb fastmult vfp edsp thumbee neon vfpv3 tls vfpv4 idiva idivt vfpd32 lpae evtstrm 
CPU implementer	: 0x41
CPU architecture: 7
CPU variant	: 0x0
CPU part	: 0xc07
CPU revision	: 4

processor	: 1
model name	: ARMv7 Processor rev 4 (v7l)
BogoMIPS	: 50.52
Features	: half thumb fastmult vfp edsp thumbee neon vfpv3 tls vfpv4 idiva idivt vfpd32 lpae evtstrm 
CPU implementer	: 0x41
CPU architecture: 7
CPU variant	: 0x0
CPU part	: 0xc07
CPU revision	: 4

Hardware	: Allwinner sun7i (A20) Family
Revision	: 0000
```

So our device is ARM model `v7l` ; this means is a 32bit CPU, if you are curious there's also a [reference manual](https://dl.linux-sunxi.org/A20/A20%20User%20Manual%202013-03-22.pdf) around. Now we will work from a development machine.

### Get Rusty

Let's check rust support:

```bash
[x86]$ rustup target list | grep armv7
armv7-linux-androideabi
armv7-unknown-linux-gnueabi
armv7-unknown-linux-gnueabihf
armv7-unknown-linux-musleabi
armv7-unknown-linux-musleabihf
armv7a-none-eabi
armv7r-none-eabi
armv7r-none-eabihf
```

Plenty of options! I'd leave out android and musl variants for now.

```bash
[x86]$ cargo init tryarm
     Created binary (application) package
[x86]$ cd tryarm      
[x86]$ cargo build --target armv7-unknown-linux-gnueabihf

error: could not compile `tryarm` (bin "tryarm") due to 1 previous error
```

### Please retry 

Seems not sufficient ... Let's try [cross tool](https://github.com/rust-embedded/cross) from the rust embedded team

```bash
[x86]$ cargo install cross
[x86]$ /home/andrea/.cargo/bin/cross build --target armv7-unknown-linux-gnueabihf

Trying to pull ghcr.io/cross-rs/armv7-unknown-linux-gnueabihf:0.2.5...
Getting image source signatures
Copying blob 5b4afa60d436 [===============================>------] 146.3MiB / 172.0MiB | 6.6 M
Copying blob 5b4afa60d436 done   | 
Copying blob 58690f9b18fc done   | 
Copying blob da8ef40b9eca done   | 
Copying blob b51569e7c507 done   | 
Copying blob 6c052f8b0b21 done   | 
Copying blob fb15d46c38dc done   | 
Copying blob 5afa4c181482 done   | 
Copying blob b9d42a766612 done   | 
Copying blob cc716323c93e done   | 
Copying blob fe4038eab07b done   | 
Copying blob 4accd797f995 done   | 
Copying blob 3db4794ce9a5 done   | 
Copying blob 8b1f228d2fc0 done   | 
Copying blob 05f315b1fff9 done   | 
Copying blob c0190749220c done   | 
Copying blob 55483985fe64 done   | 
Copying blob df8b7a9f8281 done   | 
Copying blob 9de25b0c2608 done   | 
Copying config 32cf786140 done   | 
Writing manifest to image destination
   Compiling tryarm v0.1.0 (/project)
    Finished dev [unoptimized + debuginfo] target(s) in 0.26s
```

This tool pulls a container with the right compiler toolchain and use it to build your project. Seems our program is in place, and it's compiled! 


```bash
[x86]$ file target/armv7-unknown-linux-gnueabihf/debug/tryarm
target/armv7-unknown-linux-gnueabihf/debug/tryarm: ELF 32-bit LSB pie executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=7ff3fc41deb8b4820cc64ff2857cddbfa577111c, with debug_info, not stripped

[x86]$ objdump -d target/armv7-unknown-linux-gnueabihf/debug/tryarm
    3428:       e59d300c        ldr     r3, [sp, #12]
    342c:       e0802080        add     r2, r0, r0, lsl #1
    3430:       e08b108b        add     r1, fp, fp, lsl #1
    3434:       e1a09003        mov     r9, r3
    3438:       e1a00003        mov     r0, r3
    343c:       e7b91181        ldr     r1, [r9, r1, lsl #3]!
    3440:       e7b02182        ldr     r2, [r0, r2, lsl #3]!
    3444:       e5993004        ldr     r3, [r9, #4]
    3448:       e5904004        ldr     r4, [r0, #4]
    344c:       e0521001        subs    r1, r2, r1
    3450:       e0d41003        sbcs    r1, r4, r3
```

### Run baby run

So, let's transfer our binary to the device and run it

```bash
[x86]$ scp target/armv7-unknown-linux-gnueabihf/debug/tryarm user@cubietruck:/home/user
user@cubietruck's password: 
tryarm                                                      100% 3443KB   5.3MB/s   00:00 
```

Switching to the device shell:


```bash
[user@arm ~]$ ./tryarm 
Hello, world!
[user@arm ~]$ ldd tryarm 
	linux-vdso.so.1 (0xbefbd000)
	libgcc_s.so.1 => /usr/lib/libgcc_s.so.1 (0xb6e40000)
	librt.so.1 => /usr/lib/librt.so.1 (0xb6e20000)
	libpthread.so.0 => /usr/lib/libpthread.so.0 (0xb6e00000)
	libdl.so.2 => /usr/lib/libdl.so.2 (0xb6de0000)
	libc.so.6 => /usr/lib/libc.so.6 (0xb6c40000)
	/lib/ld-linux-armhf.so.3 => /usr/lib/ld-linux-armhf.so.3 (0xb6eda000)
```

It's working :smile:

### Future awaits

We are able to compile and run Rust code on our little device, so this Proof of Concept is over. In the future we will use it to develop and test software on a foreign architecture.

Some resources for further reference:

- https://www.modio.se/cross-compiling-rust-binaries-to-armv7.html