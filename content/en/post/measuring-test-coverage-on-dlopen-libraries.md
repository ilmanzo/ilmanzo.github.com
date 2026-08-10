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

## 🧭 [Where we left off](https://www.youtube.com/watch?v=pAgnJDJN4VA)

Welcome back to our technical journey on measuring binary test coverage!

In [part 4](https://ilmanzo.github.io/post/measuring-test-coverage-with-ebpf/) we introduced **[funkoverage](https://github.com/ilmanzo/BinaryCoverage/)**, a native, high-performance eBPF-based coverage tracer that leverages `uprobe_multi` to capture function entry events in GNU/Linux with less than 2% overhead. It parses static library dependencies using `ldd` during installation and maps uprobes to all discovered functions.

But there was a big fat elephant in the room: **`dlopen()`**.

Some of the most complex, modular software in the world — such as web servers with dynamic modules, plugin-based enterprise applications, and multi-protocol databases — load their dependencies *at runtime* on-the-fly. Because these libraries are not declared in the ELF binary's `DT_NEEDED` header, they are invisible to `ldd` during installation.

Today, we are going to chase the dynamic loading ghost, explore how we solved this with an elegant, highly scalable, event-driven eBPF JIT instrumentation strategy, and battle-test it live on standard, unmodified production binaries like **Nginx** and **OpenSSL**!

<!--more-->

![plug](/img/pexels-realtoughcandy-11034131.jpg)
*(Image courtesy of https://www.pexels.com/@realtoughcandy/)*

## 🕳️ [The dynamic loading ghost](https://www.youtube.com/watch?v=VqoyKzgkqR4)

When a program loads a shared library dynamically at runtime, it uses the standard POSIX functions `dlopen()` or `dlmopen()`:

```c
void *handle = dlopen("./libplugin.so", RTLD_NOW);
```

Because this library is not mapped when the program starts, compile-time and link-time dependency analysis tools like `ldd` are completely blind to it.

If we run `ldd` on standard distro executables like `nginx`, we see standard dynamic dependencies, but we are completely blind to runtime-loaded providers or plug-ins like OpenSSL's `legacy.so`. This means that as soon as the application calls dynamically loaded code, our coverage maps go dark.

---

## 🧮 [Active polling vs. event-driven JIT](https://www.youtube.com/watch?v=bWXazVhlyxQ)

How do we solve this?

One naive approach is to run a loop in the Go shim that periodically polls `/proc/<pid>/maps` (say, every 10ms) to detect newly loaded libraries.
However, **polling does not scale**.

If we have **5,000 instrumented binaries** installed on a system, active polling would require reading `/proc/<pid>/maps` up to **500,000 times per second**. This triggers severe CPU cache thrashing, high I/O wait times, and process throttling.

To keep the tool lightweight and enterprise-ready, we designed an **event-driven JIT (just-in-time) instrumentation** strategy:

1. **Uretprobe on `dlopen`**: At startup, `funkoverage` checks a short list of standard glibc paths for one that actually exports the `dlopen` symbol (fast path), falling back to a one-time `/proc/<pid>/maps` scan if none match. It then attaches a return uprobe (`uretprobe`) there.
2. **The special token**: When `dlopen` successfully completes inside the target application and returns a non-NULL handle, our eBPF program catches the event and writes a reserved token (`0xFFFFFFFF`) into the lockless kernel-to-userspace `events` ring buffer.
3. **Event-driven parse**: The Go shim receives the `0xFFFFFFFF` event in its background loop. Only *then* does it walk `/proc/<pid>/maps` — for *every* pid currently in the kernel-side `watched` map, not just the root process — to scan for newly mapped `.so` files. That map is what makes multi-process tracing work at all: a `sched_process_fork` tracepoint copies a process's watched bit to its children as they're born, so a forked worker calling `dlopen()` on its own gets caught too.
4. **JIT attach**: The shim parses the new library's ELF symbol table on-the-fly, matches them against current filter regexes, and registers new uprobes dynamically using a single `UprobeMulti` system call.

This keeps steady-state overhead at **0% CPU** and **0% I/O**!

### Show me the code

The eBPF side is a single `uretprobe` on `dlopen`, reading the return value straight off the architecture's return register:

```c
SEC("uretprobe/dlopen")
int trace_dlopen_return(struct pt_regs *ctx)
{
    __u32 tgid = bpf_get_current_pid_tgid() >> 32;
    if (!bpf_map_lookup_elem(&watched, &tgid))
        return 0;

#if defined(__x86_64__)
    void *handle = (void *)ctx->ax;
#elif defined(__aarch64__)
    void *handle = (void *)ctx->regs[0];
#endif
    if (!handle)
        return 0;

    struct event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e)
        return 0;
    e->func_idx = 0xFFFFFFFF; // reserved token: "a library just got dlopen'd"
    bpf_ringbuf_submit(e, 0);
    return 0;
}
```

On the Go side, `Tracer.Start` locates the right libc/libdl and attaches to it with the exact same `link.OpenExecutable` + `Uretprobe` API `cilium/ebpf` already gives us for regular function uprobes:

```go
libcPath, err := findLibcPath(rootPID)
if err == nil {
    if ex, err := link.OpenExecutable(libcPath); err == nil {
        if l, err := ex.Uretprobe("dlopen", t.objs.TraceDlopenReturn, nil); err == nil {
            t.addLink(l)
        }
    }
}
```

And on the consumer side, the ringbuf read loop just special-cases the reserved token:

```go
idx := binary.LittleEndian.Uint32(record.RawSample[:4])
if idx == 0xFFFFFFFF {
    t.handleDynamicLoad() // walk watched pids, diff /proc/*/maps, JIT-attach new libs
    continue
}
```

`handleDynamicLoad` is where the actual JIT work happens: diff every watched process's memory map against what's already instrumented, read the new library's ELF symbol table, run it through the same `--include`/`--exclude` filters used at install time, and attach a fresh `UprobeMulti` batch — all without the target process ever noticing.

---

## 🩺 [Overcoming real-world distro obstacles](https://www.youtube.com/watch?v=btPJPFnesV4)

Moving this design from a "dummy program" to real-world production binaries like `nginx` and `openssl` threw some heavy technical curveballs at us. Here is how we solved them:

### A. The execute-bit bug in `cilium/ebpf`
Standard system shared libraries (like `/usr/lib/x86_64-linux-gnu/ossl-modules/legacy.so` or `libcrypto.so.3`) are packaged without the executable bit set on disk (permissions are `0644`).
In `github.com/cilium/ebpf` version `v0.21.0`, `link.OpenExecutable` strictly verified this execute bit and threw `file is not executable` errors, blocking uprobes.
* **The fix**: We upgraded `github.com/cilium/ebpf` to `v0.22.0` where this strict permission check is removed, allowing seamless uprobe attachment on all shared object files on disk.

### B. Resilient symbol and DWARF fallbacks
Production executables are stripped of `.symtab` and DWARF debugging logs. To prevent `enumerate` crashes:
* **The fix**: We updated the symbol parser to handle DWARF decoding errors gracefully and automatically fall back to `.dynsym` (dynamic symbol table) parsing, which is guaranteed to be present for dynamically loaded plugins!

### C. Seamless 100% silence for CI/CD
To replace `/usr/sbin/nginx` transparently, the wrapped binary must behave **identically** to the original. Any debugging logs from the Go shim on `stdout` or `stderr` would break automation scripts.
* **The fix**: We introduced a silent mode by gating all JIT attachment and logging diagnostics behind a `FUNKOVERAGE_DEBUG` environment variable. In normal operation, the shim produces **exactly 0 extra bytes of output** on `stdout` or `stderr`!

### D. `CAP_SYS_RESOURCE` on modern kernels
On kernels ≥ 6.6 running memcg-based BPF memory accounting (the default on current distros), `cilium/ebpf`'s `rlimit.RemoveMemlock()` is supposed to be a no-op — the kernel already does its own accounting, no `RLIMIT_MEMLOCK` bump needed. But its own probe for "does this kernel support memcg accounting" can misfire under BPF memory pressure and fall back to the old `RLIMIT_MEMLOCK` path, which requires `CAP_SYS_RESOURCE`. Without it, the shim hard-failed before even exec'ing the real binary (`remove memlock: operation not permitted`).
* **The fix**: We grant `CAP_SYS_RESOURCE` to the shim binary alongside the capabilities it already needed, so that rare-but-real fallback path doesn't take the whole tracer down with it.

---

## 🏆 [Battle-testing live on Nginx](https://www.youtube.com/watch?v=qVHyl0P_P-M)

We installed standard, stripped `nginx` on our machine, wrapped `/usr/sbin/nginx` permanently, and ran a configuration check:

```bash
$ sudo ./funkoverage install /usr/sbin/nginx
Installed shim for /usr/sbin/nginx (original at /var/coverage/bin/nginx)

$ sudo /usr/sbin/nginx -t
2026/07/28 20:38:30 [emerg] 47221#47221: open() "/etc/letsencrypt/options-ssl-nginx.conf" failed (2: No such file or directory) in /etc/nginx/sites-enabled/example.duckdns.org:90
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

## 🩹 Round two: hardening after a deeper look

A prototype that works once on your own machine and a feature you can trust in production are two different things. We put the JIT dlopen path through an independent code review — and a `go test -race` run turned up a real bug within minutes:

- **A race condition on shutdown.** The dlopen handler runs on a background goroutine, appending newly discovered library links to a shared slice, while `Stop()` was concurrently closing and clearing that *same* slice from the caller's goroutine during teardown. Unsynchronized concurrent access — exactly the kind of bug that only shows up under load, at the worst possible time. Fixed with a small mutex around the shared state.
- **Filters silently skipped dynamic libraries.** `--include`/`--exclude` regex filters worked correctly against statically-enumerated functions, but anything discovered later via `dlopen` bypassed them entirely. We now serialize the compiled filter patterns into a small `.filter.json` sidecar at install time, and the shim re-applies the exact same logic to whatever it discovers at runtime.
- **A capacity ceiling with no alarm.** The kernel-side dedup map is sized once, at BPF load time, with headroom reserved for functions discovered later. Past that headroom, cookie lookups silently return `NULL` in the kernel — the call is simply dropped, with nothing logged anywhere. For a coverage tool, a silent false negative is about the worst failure mode there is. Now it clips and warns loudly instead.
- **A debug `bpf_printk` we forgot to remove.** uprobes attach per file+offset, system-wide — not per-process. Two debug prints in the dlopen uretprobe were firing on *every* `dlopen()` call on the whole machine, not just the one we cared about, quietly working against the "0% overhead at scale" promise from Part 4. Gone now.
- **Older glibc support.** `dlopen` only moved into `libc.so.6` in glibc 2.34 (2021) — before that it lived in `libdl.so.2`. The uretprobe attach logic now verifies the symbol is actually present in a candidate library before committing to it, instead of just checking the file exists on disk.

Two more came from writing tests, not from reading code — which is exactly the point of writing them:

- `isSystemLib()`, the heuristic that skips known system libraries to keep dynamic traces lean, had a regex where the `libstdc++` alternative could *never* actually match — a `\b` word-boundary anchor right after a `+` character can't fire, since `+` isn't a word character. `libstdc++.so.6` was quietly getting fully instrumented instead of skipped, every single time.
- The ELF symbol reader for dynamically loaded libraries only fell back to `.dynsym` if reading `.symtab` failed outright — but glibc's own `libc.so.6` ships a `.symtab` that *succeeds* while omitting exported functions like `dlopen` itself, which live only in `.dynsym`. Fix: union both tables instead of picking one.

---

## 🏁 [Conclusion](https://www.youtube.com/watch?v=8fPf6L0XNvM)

With this event-driven JIT architecture, `funkoverage` extends its uprobe-based tracing to libraries loaded at runtime via `dlopen()`, on top of the statically enumerated dependencies from Part 4 — pure Go and eBPF, running natively on both x86_64 and ARM64.

As of this post the project sits at **v0.8.0**. Next on the list, per the project's own roadmap: dropping the last `ldd` fork-exec in favor of parsing `DT_NEEDED` directly via `debug/elf`, and a guard that refuses to `install` on top of an already-shimmed binary.

The project is at [github.com/ilmanzo/BinaryCoverage](https://github.com/ilmanzo/BinaryCoverage) — issues, feedback, and pull requests are very welcome!

Feel free to leave comments and feedback, happy hacking! :wave:

![eBPF logo](/img/ebpf_logo.png)
