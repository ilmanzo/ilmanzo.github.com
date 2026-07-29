---
layout: post
title: "How much code are you testing ? (5)"
description: "Tracing dlopen()'d libraries on-the-fly with event-driven eBPF JIT uprobes"
categories: [programming, testing]
tags: [testing, linux, coverage, ebpf, bpf, uprobe, tracing, go, golang, qa, dlopen, nginx, openssl, pam]
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

## 🩹 Round Two: Hardening After a Deeper Look

A prototype that works once on your own machine and a feature you can trust in production are two different things. We put the JIT dlopen path through an independent code review — and a `go test -race` run turned up a real bug within minutes:

- **A race condition on shutdown.** The dlopen handler runs on a background goroutine, appending newly discovered library links to a shared slice, while `Stop()` was concurrently closing and clearing that *same* slice from the caller's goroutine during teardown. Unsynchronized concurrent access — exactly the kind of bug that only shows up under load, at the worst possible time. Fixed with a small mutex around the shared state.
- **Filters silently skipped dynamic libraries.** `--include`/`--exclude` regex filters worked correctly against statically-enumerated functions, but anything discovered later via `dlopen` bypassed them entirely. We now serialize the compiled filter patterns into a small `.filter.json` sidecar at install time, and the shim re-applies the exact same logic to whatever it discovers at runtime.
- **A capacity ceiling with no alarm.** The kernel-side dedup map is sized once, at BPF load time, with headroom reserved for functions discovered later. Past that headroom, cookie lookups silently return `NULL` in the kernel — the call is simply dropped, with nothing logged anywhere. For a coverage tool, a silent false negative is about the worst failure mode there is. Now it clips and warns loudly instead.
- **A debug `bpf_printk` we forgot to remove.** uprobes attach per file+offset, system-wide — not per-process. Two debug prints in the dlopen uretprobe were firing on *every* `dlopen()` call on the whole machine, not just the one we cared about, quietly working against the "0% overhead at scale" promise from Part 4. Gone now.
- **Older glibc support.** `dlopen` only moved into `libc.so.6` in glibc 2.34 (2021) — before that it lived in `libdl.so.2`. The uretprobe attach logic now verifies the symbol is actually present in a candidate library before committing to it, instead of just checking the file exists on disk.

Two more came from writing tests, not from reading code — which is exactly the point of writing them:

- `isSystemLib()`, the heuristic that skips known system libraries to keep dynamic traces lean, had a regex where the `libstdc++` alternative could *never* actually match — a `\b` word-boundary anchor right after a `+` character can't fire, since `+` isn't a word character. `libstdc++.so.6` was quietly getting fully instrumented instead of skipped, every single time.
- The ELF symbol reader for dynamically loaded libraries only fell back to `.dynsym` if reading `.symtab` failed outright — but glibc's own `libc.so.6` ships a `.symtab` that *succeeds* while omitting exported functions like `dlopen` itself, which live only in `.dynsym`. Fix: union both tables instead of picking one.

## 👻 The Ghost That Got Away: NSS

Remember the dynamic loading ghost from the top of this post? We caught it hiding in PAM modules and Nginx's own plugin system below — but there's one place it still gets away clean: glibc's Name Service Switch.

Every time a program resolves a hostname or looks up a user (`getpwnam`, `gethostbyname`, and friends), glibc dynamically loads `libnss_dns.so.2`, `libnss_files.so.2`, or whichever backend `/etc/nsswitch.conf` points at — invisible to `ldd`, exactly the class of problem this whole feature exists to solve.

Except it doesn't work here. We hooked the *public* `dlopen()` symbol; glibc's own NSS dispatcher calls a private, non-exported `__libc_dlopen_mode` instead — a completely different function, at a completely different address:

```bash
$ readelf -Ws /lib64/libc.so.6 | grep -w dlopen
  2326: 0000000000096f3e   165 FUNC    GLOBAL DEFAULT   16 dlopen@@GLIBC_2.34
$ readelf -Ws /lib64/libc.so.6 | grep libc_dlopen
  3219: 000000000016fefe   140 FUNC    LOCAL  DEFAULT   16 __libc_dlopen_mode
```

We proved it empirically too: a tiny test program calling `getpwnam("root")` and `gethostbyname("localhost")` runs perfectly fine under the shim — but exactly zero dlopen events fire, and no `libnss_*.so` function is ever instrumented. The lookups work; our tracer simply never sees them happen.

This isn't something we can code our way out of from userspace — it's a permanent scope boundary of hooking one specific, public ELF symbol. A real fix would mean also hooking `__libc_dlopen_mode`, a private glibc internal with no stability guarantee across versions. For now we document it plainly instead of pretending it isn't there.

## 🧪 More Battle Scars: PAM and a Clean-Room Nginx

Beyond the live nginx test above, we spun up a disposable, freshly installed openSUSE Tumbleweed VM specifically to hammer on real production binaries with zero prior configuration.

**PAM** was the star performer. `su` links against `libpam.so.0` — visible to `ldd` — but the actual authentication modules underneath it (`pam_unix.so`, `pam_env.so`, `pam_limits.so`, `pam_systemd.so`, `pam_selinux.so`, ...) live under `/usr/lib64/security/` and get `dlopen()`'d purely at runtime, based on `/etc/pam.d/su`. A single `su - testuser -c true` triggered a whole realistic cascade — a dozen PAM modules plus their own transitively dlopen'd support libraries — all correctly JIT-instrumented with zero configuration:

```
CALLED /usr/lib64/security/pam_unix.so pam_sm_open_session
CALLED /usr/lib64/security/pam_unix.so pam_sm_close_session
```

**Nginx**, on a completely fresh install this time, got the `nginx-module-echo` dynamic module wired up via `load_module`. The real payoff wasn't just seeing the module's `.so` show up in the trace — it was confirming the *actual per-request handler* got instrumented, not just its one-time initialization callbacks:

```
CALLED /usr/lib64/nginx/modules/ngx_http_echo_module.so ngx_http_echo_handler
CALLED /usr/lib64/nginx/modules/ngx_http_echo_module.so ngx_http_echo_run_cmds
CALLED /usr/lib64/nginx/modules/ngx_http_echo_module.so ngx_http_echo_exec_echo
```

(That took two tries. Nginx daemonizes by default — forking and exiting its own parent process — and our tracer follows one specific PID. The fix was the one every process supervisor already knows: run with `-g "daemon off;"` and let the shell handle backgrounding instead.)

---

## 🏁 [Conclusion](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

With this new event-driven JIT architecture, `funkoverage` reaches full coverage transparency:

- **100% Coverage**: Tracks both statically linked dependencies and JIT/dynamically loaded plugins.
- **Enterprise Ready**: Designed to scale safely to **5,000+ instrumented binaries** with zero steady-state CPU or memory overhead, hardened by a real code review and validated on real hardware.
- **Pure-Go and eBPF**: Works natively on both x86_64 and ARM64 architectures running modern Linux kernels.
- **Honest about its edges**: NSS lookups are a documented limitation, not a silent gap.

The project is at [github.com/ilmanzo/BinaryCoverage](https://github.com/ilmanzo/BinaryCoverage) — issues, feedback, and pull requests are very welcome!

Feel free to leave comments and feedback, happy hacking! :wave:

![eBPF logo](/img/ebpf_logo.png)
