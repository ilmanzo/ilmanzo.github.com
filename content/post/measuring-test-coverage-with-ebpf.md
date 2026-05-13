---
layout: post
title: "How much code are you testing ? (4)"
description: "Native eBPF binary coverage with funkoverage. No SDK, no recompilation, any architecture"
categories: [programming, testing]
tags: [testing, linux, coverage, ebpf, bpf, uprobe, tracing, go, golang, qa]
series: ["How much code are you testing?"]
series_order: 4
author: Andrea Manzini
date: 2026-05-13
---

## 🧭 [Where we left off](https://www.youtube.com/watch?v=uB1D9wWxd2w)

Welcome back to our ongoing series on measuring test coverage for binary programs!

In [part 1](https://ilmanzo.github.io/post/measuring-coverage-of-integration-tests/) we used Go's built-in `-cover` flag — clean and accurate, but only works if you own the source and can recompile. In [part 2](https://ilmanzo.github.io/post/measuring-test-coverage-on-binaries/) we used `valgrind` and `gdb` to trace `gzip` without touching its source. In [part 3](https://ilmanzo.github.io/post/pintool-function-tracing/) we explored Intel PIN, a proper dynamic binary instrumentation framework — powerful, but it came with a ~100MB proprietary C++ SDK and was limited to x86_64.

At the end of that post I promised we'd go further: *full automation, any binary, no recompilation*. Today we make good on that promise with a native eBPF approach, and the result is a tool called **funkoverage**.

![probe](/img/pexels-tanfeez-10699357.jpg)
(image courtesy of https://www.pexels.com/@tanfeez/)

## 🕳️ [Why eBPF changes everything](https://www.youtube.com/watch?v=7W3yz6abJkU)

[eBPF](https://ebpf.io/) is a Linux kernel technology that lets you run small sandboxed programs *inside the kernel* in response to events — without loading kernel modules or patching the kernel itself. For tracing purposes, this means we can hook function entry points with **uprobes** and receive notifications in userspace via a ring buffer, all with negligible overhead.

Two eBPF features make this particularly attractive for coverage measurement:

**`uprobe_multi`** (available since Linux 6.6) lets you attach uprobes for an entire binary or library in a *single syscall*, passing all symbol names and "cookies" at once. Previously you needed one syscall per function — at 8,000 functions that's 8,000 syscalls just to set up. Now it's one.

**Kernel-side first-call deduplication**: inside the BPF program, we use an atomic compare-and-swap operation on a per-function flag stored in a kernel map. This means each function fires exactly one event to userspace, no matter how many times it is called during the program's lifetime. For coverage purposes this is exactly what we want: a clean yes/no signal with no noise.

Here's how the approaches compare:

| Approach | Overhead | SDK required | Architecture | First-call dedup |
|---|---|---|---|---|
| valgrind/callgrind | ~10–20× slower | None | x86_64 | No |
| Intel PIN | ~5–10× slower | ~100MB C++ SDK | x86_64 | No |
| **eBPF uprobe_multi** | **~1–2% overhead** | **None** | **ANY** | **Yes** |

The overhead difference is significant in practice. With valgrind, even a trivial `gzip -h` takes half a second. With uprobes, it takes milliseconds — the program runs at essentially native speed.

## 🥷 [A transparent impostor](https://www.youtube.com/watch?v=sfCLt0kTd5E)

[funkoverage](https://github.com/ilmanzo/BinaryCoverage) is a pure-Go tool that uses this eBPF infrastructure to give you function-level coverage on any ELF binary, without source code or recompilation.

The design is built around two cooperating binaries:

```
┌──────────────────┐         ┌──────────────────────────┐
│   funkoverage    │  CLI    │    funkoverage-shim      │
│  install/report  │         │  transparent replacement │
└──────────────────┘         └──────────────────────────┘
```

**`funkoverage`** is the CLI you interact with: it installs and uninstalls the shim, enumerates functions, and generates coverage reports.

**`funkoverage-shim`** is a "tiny" Go binary that gets installed *in place of* the target binary. It's completely generic — it doesn't know anything about `gzip` or any other program. When invoked, it reads a JSON sidecar file to discover which functions to hook, attaches the BPF probes, and then transparently runs the real binary.

Running `sudo funkoverage install /usr/bin/gzip` performs these steps:

1. Moves the real `gzip` binary to `/var/coverage/bin/gzip`
2. Enumerates all functions from the symbol table (falls back to DWARF if needed)
3. Writes a `gzip.funcs.json` sidecar with the symbol list
4. Copies the shim binary to `/usr/bin/gzip`
5. Runs `setcap cap_bpf,cap_perfmon+ep` on the shim so it can attach uprobes without running as root

From that point on, every invocation of `gzip` transparently runs through the shim. The shim's runtime sequence looks like this:

```txt
user runs "gzip -h"
      │
      ▼
/usr/bin/gzip  ← this is now the shim
      │
      ├── read gzip.funcs.json
      ├── fork a child process (paused on a pipe)
      ├── load embedded BPF program
      ├── link.UprobeMulti(all symbols)   ← one syscall per image
      ├── seed kernel "watched" map with child PID
      ├── start ring buffer reader goroutine
      │
      ├── unblock child via pipe → child exec()s real gzip
      │
      ├── BPF fires on first call to each function
      │       └── event → ring buffer → demangle → _called.log
      │
      └── child exits → detach probes → drain buffer → close log
```

No `LD_PRELOAD`, no `ptrace`, no binary patching. The real binary runs unmodified inside the child process; the parent shim just watches what happens at the kernel level.

## 🩺 [Hooking gzip, live](https://www.youtube.com/watch?v=jEjVD3fqTkk)

We'll use `gzip` again — the same target as in part 2 — so we can compare the numbers directly.

Build and install funkoverage (you'll need Go 1.26+ and Linux kernel ≥ 6.6 with BTF enabled):

```bash
$ git clone https://github.com/ilmanzo/BinaryCoverage
$ cd BinaryCoverage
$ ./build.sh
$ sudo cp funkoverage funkoverage-shim /usr/local/bin/
```

Now install the shim over gzip:

```bash
$ sudo funkoverage install /usr/bin/gzip
✓ moved /usr/bin/gzip → /var/coverage/bin/gzip
✓ enumerated 80 functions
✓ shim installed at /usr/bin/gzip (cap_bpf,cap_perfmon+ep)
```

Run our simple smoke test from part 2:

```bash
$ gzip -h
Usage: gzip [OPTION]... [FILE]...
Compress or uncompress FILEs (by default, compress FILES in-place).
...
```

The output is identical — `gzip` behaves exactly as before. But now we have a log file:

```bash
$ tail -5 /var/coverage/data/gzip_*_called.log
CALLED /var/coverage/bin/gzip main
CALLED /var/coverage/bin/gzip try_help
CALLED /var/coverage/bin/gzip license
CALLED /var/coverage/bin/gzip rpl_printf
CALLED /var/coverage/bin/gzip progerror
```

Generate the coverage report:

```bash
$ funkoverage report /var/coverage/data /tmp/report
$ cat /tmp/report/gzip.txt
Functions: 9/80 (11.25%)
```

**11.25%** — exactly what valgrind reported in part 2. Reassuring! But this time `gzip -h` ran in milliseconds, not half a second.

## 🌒 [Chasing the dark functions](https://www.youtube.com/watch?v=8WEtxJ4-sh4)

The shim appends to the log file on each run, and the report accumulates. Let's follow the same progression as part 2 and watch the coverage grow.

Check the version:

```bash
$ gzip -V
$ funkoverage report /var/coverage/data /tmp/report
Functions: 10/80 (12.50%)
```

Try an error path — a non-existent file:

```bash
$ gzip foobar
gzip: foobar: No such file or directory
$ funkoverage report /var/coverage/data /tmp/report
Functions: 19/80 (23.75%)
```

That jumped — error-handling code exercised functions we hadn't hit before. Now let's do some actual compression:

```bash
$ echo "hello funkoverage" > /tmp/test.txt
$ gzip /tmp/test.txt
$ gzip -d /tmp/test.txt.gz
$ funkoverage report /var/coverage/data /tmp/report
Functions: 52/80 (65.00%)
```

🎉 Same progression as valgrind: 11% → 23% → 65%. The HTML report also shows the *uncalled* functions by name, which is handy for knowing exactly where your test suite still has gaps.

## 🌍 [One binary, any chip](https://www.youtube.com/watch?v=K0HSD_i2DvA)

When we extended funkoverage to support ARM64, we didn't need to change the BPF program logic at all — the eBPF instruction set is architecture-independent. What we needed was to compile the BPF C code for each target architecture and ship both objects in the repository.

The `bpf2go` tool from the cilium/ebpf project generates a Go file for each architecture, and Go's build tag mechanism selects the right one at compile time:

```
tracer_x86_bpfel.go   → //go:build 386 || amd64
tracer_arm64_bpfel.go → //go:build arm64
```

The pre-generated objects are checked into the repository, so a normal build only needs Go — no Clang or kernel headers required. On an ARM64 machine (a Raspberry Pi, a Graviton cloud instance, an Apple Silicon VM), the exact same CLI and workflow applies.

## 🏁 [The coverage you were owed](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

We've come a long way from the humble `go build -cover` of part 1. With eBPF and `uprobe_multi` we now have a tool that:

- Works on *any* ELF binary — vendor tools, distro packages, daemons — without source code or recompilation
- Adds negligible runtime overhead, making it practical even for longer test suites
- Produces clean, first-call-only coverage data without manual log parsing or glue scripts
- Runs on both x86_64 and ARM64 with no changes to the workflow

If you're writing integration tests for a binary you don't control, funkoverage gives you the coverage feedback loop you've been missing.

The project is at [github.com/ilmanzo/BinaryCoverage](https://github.com/ilmanzo/BinaryCoverage) — issues and pull requests are very welcome.

If you are interested in this approach, also check out [xcover](https://github.com/maxgio92/xcover), another eBPF-based test coverage tool. It was recently presented in a lightning talk at FOSDEM 2026 ([slides](https://fosdem.org/2026/events/attachments/CNPVJL-lightning_lightning_talks_1/slides/267016/xcover_c_2wnfgpz.pdf)).

Feel free to leave comments and feedback, happy hacking! :wave:

![eBPF logo](/img/ebpf_logo.png)
