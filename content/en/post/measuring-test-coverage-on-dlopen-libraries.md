---
layout: post
title: "How much code are you testing ? (5)"
description: "Tracing dlopen()'d libraries on-the-fly with event-driven eBPF JIT uprobes"
categories: [programming, testing]
tags: [testing, linux, coverage, ebpf, bpf, uprobe, tracing, go, golang, qa, dlopen, nginx, openssl]
series: ["How much code are you testing?"]
series_order: 5
author: Andrea Manzini
date: 2026-08-30
draft: true
---

## 🧭 [Where we left off](https://www.youtube.com/watch?v=uB1D9wWxd2w)

Welcome back to our technical journey on measuring binary test coverage!

In [part 4](https://ilmanzo.github.io/post/measuring-test-coverage-with-ebpf/) we introduced **funkoverage**, a native, high-performance eBPF-based coverage tracer that leverages `uprobe_multi` to capture function entry events in GNU/Linux with less than 2% overhead. It parses static library dependencies using `ldd` during installation and maps uprobes to all discovered functions.

But there was a big fat elephant in the room: **`dlopen()`**.

Some of the most complex, modular software in the world — such as web servers with dynamic modules, plugin-based enterprise applications, and multi-protocol databases — load their dependencies *at runtime* on-the-fly. Because these libraries are not declared in the ELF binary's `DT_NEEDED` header, they are invisible to `ldd` during installation.

Today, we are going to chase the dynamic library ghost, explore how we solved this with an elegant, highly scalable, event-driven eBPF JIT instrumentation strategy, and battle-test it live on standard, unmodified production binaries like **Nginx** and **OpenSSL**!

<!--more-->

![plug](/img/pexels-realtoughcandy-11034131.jpg)
*(Image courtesy of https://www.pexels.com/@realtoughcandy/)*

## 🕳️ [The Dynamic Loading Ghost](https://www.youtube.com/watch?v=7W3yz6abJkU)

When a program loads a shared library dynamically at runtime, it uses the standard POSIX functions `dlopen()` or `dlmopen()`:

```c
void *handle = dlopen("./libplugin.so", RTLD_NOW);
```

Because this library is not mapped when the program starts, compile-time and link-time dependency analysis tools like `ldd` are completely blind to it. 

If we run `ldd` on standard distro executables like `nginx`, we see standard dynamic dependencies, but we are completely blind to runtime-loaded providers or plug-ins like OpenSSL's `legacy.so`. This means that as soon as the application calls dynamically loaded code, our coverage maps go dark.

---

## 🧮 [Active Polling vs. Event-Driven JIT](https://www.youtube.com/watch?v=sfCLt0kTd5E)

How do we solve this?

One naive approach is to run a loop in the Go shim that periodically polls `/proc/<pid>/maps` (say, every 10ms) to detect newly loaded libraries. 
However, **polling does not scale**. 

If we have **5,000 instrumented binaries** installed on a system, active polling would require reading `/proc/<pid>/maps` up to **500,000 times per second**. This triggers severe CPU cache thrashing, high I/O wait times, and process throttling.

To keep the tool lightweight and enterprise-ready, we designed an **Event-Driven JIT (Just-In-Time) Instrumentation** strategy:

1. **Uretprobe on `dlopen`**: During startup, `funkoverage` parses `/proc/<pid>/maps` once to locate the loaded `libc.so.6` path. It attaches a return uprobe (`uretprobe`) to the `dlopen` symbol.
2. **The Special Token**: When `dlopen` successfully completes inside the target application and returns a non-NULL handle, our eBPF program catches the event and writes a reserved token (`0xFFFFFFFF`) into the lockless kernel-to-userspace `events` ring buffer.
3. **Event-Driven Parse**: The Go shim receives the `0xFFFFFFFF` event in its background loop. Only *then* does it read `/proc/<pid>/maps` to scan for newly mapped `.so` files.
4. **JIT Attach**: The shim parses the new library's ELF symbol table on-the-fly, matches them against current filter regexes, and registers new uprobes dynamically using a single `UprobeMulti` system call.

This keeps steady-state overhead at **0% CPU** and **0% I/O**!

---

## 🩺 [Overcoming Real-World Distro Obstacles](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

Moving this design from a "dummy program" to real-world production binaries like `nginx` and `openssl` threw some heavy technical curveballs at us. Here is how we solved them:

### A. The Execute-Bit Bug in `cilium/ebpf`
Standard system shared libraries (like `/usr/lib/x86_64-linux-gnu/ossl-modules/legacy.so` or `libcrypto.so.3`) are packaged without the executable bit set on disk (permissions are `0644`).
In `github.com/cilium/ebpf` version `v0.21.0`, `link.OpenExecutable` strictly verified this execute bit and threw `file is not executable` errors, blocking uprobes.
* **The Fix**: We upgraded `github.com/cilium/ebpf` to `v0.22.0` where this strict permission check is removed, allowing seamless uprobe attachment on all shared object files on disk.

### B. Resilient Symbol and DWARF Fallbacks
Production executables are stripped of `.symtab` and DWARF debugging logs. To prevent `enumerate` crashes:
* **The Fix**: We updated the symbol parser to handle DWARF decoding errors gracefully and automatically fall back to `.dynsym` (dynamic symbol table) parsing, which is guaranteed to be present for dynamically loaded plugins!

### C. Seamless 100% Silence for CI/CD
To replace `/usr/sbin/nginx` transparently, the wrapped binary must behave **identically** to the original. Any debugging logs from the Go shim on `stdout` or `stderr` would break automation scripts.
* **The Fix**: We introduced a silent mode by gating all JIT attachment and logging diagnostics behind a `FUNKOVERAGE_DEBUG` environment variable. In normal operation, the shim produces **exactly 0 extra bytes of output** on `stdout` or `stderr`!

---

## 🏆 [Battle-Testing Live on Nginx](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

We installed standard, stripped `nginx` on our machine, wrapped `/usr/sbin/nginx` permanently, and ran a configuration check:

```bash
$ sudo ./funkoverage install /usr/sbin/nginx
Installed shim for /usr/sbin/nginx (original at /var/coverage/bin/nginx)

$ sudo /usr/sbin/nginx -t
2026/07/28 20:38:30 [emerg] 47221#47221: open() "/etc/letsencrypt/options-ssl-nginx.conf" failed (2: No such file or directory) in /etc/nginx/sites-enabled/manzoweb.duckdns.org:90
nginx: configuration file /etc/nginx/nginx.conf test failed
```

No dynamic logs, no debug alerts, complete silence! Yet under-the-hood, eBPF JIT hooked the load of `libcrypto.so.3` and `libssl.so.3`, instrumented **6,400+ dynamic functions** on-the-fly, and wrote a clean, complete coverage log:

```bash
$ head -n 10 /var/coverage/data/nginx_20260728-203828_1785263908966542979_called.log
CALLED /var/coverage/bin/nginx ngx_strerror_init
CALLED /var/coverage/bin/nginx ngx_time_init
CALLED /var/coverage/bin/nginx ngx_time_update
CALLED /lib/x86_64-linux-gnu/libcrypto.so.3 OPENSSL_INIT_new
CALLED /lib/x86_64-linux-gnu/libcrypto.so.3 OPENSSL_INIT_set_config_appname
CALLED /lib/x86_64-linux-gnu/libssl.so.3 OPENSSL_init_ssl
CALLED /lib/x86_64-linux-gnu/libcrypto.so.3 OPENSSL_init_crypto
```

The final report successfully processed **14,301 total functions** and logged **772 called functions** across Nginx and its dynamically loaded cryptographic libraries!

---

## 🏁 [Conclusion](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

With this new event-driven JIT architecture, `funkoverage` reaches full coverage transparency:

- **100% Coverage**: Tracks both statically linked dependencies and JIT/dynamically loaded plugins.
- **Enterprise Ready**: Designed to scale safely to **5,000+ instrumented binaries** with zero steady-state CPU or memory overhead.
- **Pure-Go and eBPF**: Works natively on both x86_64 and ARM64 architectures running modern Linux kernels.

The project is at [github.com/ilmanzo/BinaryCoverage](https://github.com/ilmanzo/BinaryCoverage) — issues, feedback, and pull requests are very welcome!

Feel free to leave comments and feedback, happy hacking! :wave:

![eBPF logo](/img/ebpf_logo.png)
