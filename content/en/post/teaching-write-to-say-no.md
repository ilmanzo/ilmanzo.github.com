---
title: "syscalln't 🚫"
description: "Teaching write() to say no: an introduction to syscalls and fault injection, using strace to make a syscall fail on demand"
categories: ["linux", "programming"]
tags: ["linux", "kernel", "syscall", "strace", "python", "testing", "fault-injection"]
series: ["Syscall Fault Injection"]
series_order: 1
translationKey: teaching-write-to-say-no
author: Andrea Manzini
date: 2026-07-16
---

## 🤔 What's a syscall, anyway?

![A blue Mini Cooper balanced on two wheels during a stunt driving show](/img/stunt-mini-cooper.jpg)
Image credits: [Mike Norris](https://www.pexels.com/@miken/) via [Pexels](https://www.pexels.com/photo/exciting-car-stunt-show-at-saltburn-by-the-sea-34153581/)

Every time your program reads a file, writes to a socket, or allocates memory, at some point it has to ask the kernel to actually do it. That ask is a **syscall**, the narrow, well defined boundary where userspace code crosses into the kernel. `write()`, `read()`, `open()`, `mmap()`, these aren't just library functions, they're the entire vocabulary your program has for talking to the outside world. Everything else, `fwrite`, Python's `file.write()`, `std::fs::File`, is just a wrapper around this same handful of kernel entry points.

This matters because it's also the *only* place where "the outside world went wrong" can actually reach your program. A full disk, a dropped network connection, a hit file descriptor limit, none of these are bugs in your code. They're facts about the environment, and the kernel reports them to you exactly one way: a syscall returns an error. It's not lying to you. It's the kernel honestly saying "no, I can't do that right now." Whether your code actually *listens* to that "no" is another matter entirely.

## 💥 Why break things on purpose?

Here's the uncomfortable truth: most error handling code is the least tested code in any codebase. You can write a perfectly reasonable `except OSError` around a `write()` call, but if your disk never actually fills up during testing, that branch never runs. It ships untested, and the first time it *does* run is in front of a real user, with real data on the line.

Real failures like "disk full" or "connection reset" are rare and annoying to reproduce on demand. **Fault injection makes them cheap and repeatable.** Instead of hoping your error handling code works, you force the failure yourself, on your own schedule, and watch what actually happens.

There's a kernel native way to do this, `/sys/kernel/debug/fail_function`, but it needs a kernel built with fault injection debug support, which not everyone has. Good news: for the syscall boundary specifically, there's a much lower barrier tool already sitting on your system.

## 🧪 Meet progress_log

Every fault injection technique in this series gets its own small, purpose built target, no framework, no shared codebase to onboard onto first. For strace, we want something as plain as it gets.

Meet `progress_log`. It processes a batch of "items", writing one line per item to a log file as it goes, the kind of checkpoint log every batch job needs so that if it dies partway through, you know exactly where.

```python
#!/usr/bin/env python3
"""progress_log: record how far a (simulated) batch job got, one line per item.

If the job dies partway through, this log tells you exactly which item it was
on -- but only if a failed write() is caught instead of crashing silently.

Opened unbuffered (buffering=0) on purpose: Python's normal buffered file
objects can silently retry -- and succeed -- writing data on close(), even
after your code already caught and reported a write() failure for it.
Unbuffered means what you see here is exactly what happens at the syscall
level, no surprises.
"""
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <count> <path>", file=sys.stderr)
        return 1

    count = int(sys.argv[1])
    path = sys.argv[2]

    with open(path, "wb", buffering=0) as log:
        for item in range(1, count + 1):
            try:
                log.write(f"processed item {item}\n".encode())
                print(f"processed item {item}", flush=True)
            except OSError as e:
                print(f"stopped at item {item}: {e}", file=sys.stderr)
                return 1

    print(f"done: processed {count} items", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

That docstring flags something worth pausing on, even in a "keep it simple" post. A normal `open(path, "w")` buffers what you write, and when a buffered write fails, Python doesn't necessarily throw the failed bytes away. A later `close()` can flush them successfully, *after* your code already told the user it failed. `buffering=0` sidesteps that entirely: what you write is what gets syscalled, immediately, no hidden retry. That's a real footgun worth knowing about even outside fault injection, it just happens to matter a lot more *inside* it.

This `except OSError` block is our error handling code, the kind that normally never runs. Let's make it run. No build step needed:

```bash
$ chmod +x progress_log.py
$ ./progress_log.py 3 progress.log
processed item 1
processed item 2
processed item 3
done: processed 3 items
```

Tracing it shows exactly what we'd expect: a `write()` to the log file (fd 3), then a `write()` to stdout (fd 1) for the progress message, alternating.

```bash
$ strace -o baseline.strace.log -e trace=write ./progress_log.py 3 progress.log
$ cat baseline.strace.log
write(3, "processed item 1\n", 17)      = 17
write(1, "processed item 1\n", 17)      = 17
write(3, "processed item 2\n", 17)      = 17
write(1, "processed item 2\n", 17)      = 17
write(3, "processed item 3\n", 17)      = 17
write(1, "processed item 3\n", 17)      = 17
write(1, "done: processed 3 items\n", 24) = 24
+++ exited with 0 +++
```

## 🔍 First surprise: `strace --inject`

`strace` has been able to make syscalls fail on demand since version 4.15 (December 2016, from a Dmitry Levin led effort that started as a [2016 GSoC project](https://lists.strace.io/pipermail/strace-devel/2016-March/004649.html)). No kernel patches required:

```bash
$ strace -e trace=write -e inject=write:error=ENOSPC:when=3 ./prog
```

`when=3` means "fail the 3rd invocation of this syscall." Let's point it at `progress_log` and simulate a full disk on the 3rd `write()`:

```bash
$ strace -o naive.strace.log -e trace=write -e inject=write:error=ENOSPC:when=3 ./progress_log.py 5 progress.log
processed item 1
stopped at item 2: [Errno 28] No space left on device
```

Wait, **item 2** failed, not item 3. Did we miscount? The strace log says no:

```bash
$ cat naive.strace.log
write(3, "processed item 1\n", 17)      = 17
write(1, "processed item 1\n", 17)      = 17
write(3, "processed item 2\n", 17)      = -1 ENOSPC (No space left on device) (INJECTED)
write(2, "stopped at item 2: [Errno 28] No"..., 54) = 54
+++ exited with 1 +++
```

There it is. `when=3` counts the **3rd `write()` syscall the process makes, period**, and our own progress message to stdout (`processed item 1`, fd 1) is a `write()` too. The kernel doesn't know or care that we only meant to break the log file, `-e inject=write:...` matches the syscall name across every file descriptor. This is exactly the kind of assumption that trips people up the first time they reach for fault injection: the failure you get is real, just not aimed where you thought it would land.

## 🎯 Scoping the blast radius with `-P`

strace can restrict tracing, and as a side effect the injection counter too, to syscalls touching a specific path, via `-P`. On strace 7.1, a **relative** path silently matches nothing. No writes get traced, none get injected, and the program runs to completion untouched, even when the current directory is exactly where the file lives.

```bash
$ strace -o relative.strace.log -e trace=write -P progress.log \
    -e inject=write:error=ENOSPC:when=3 ./progress_log.py 5 progress.log
processed item 1
processed item 2
processed item 3
processed item 4
processed item 5
done: processed 5 items
```

Using the **absolute path** fixes it:

```bash
$ strace -o scoped.strace.log -e trace=write -P "$(pwd)/progress.log" \
    -e inject=write:error=ENOSPC:when=3 ./progress_log.py 5 progress.log
processed item 1
processed item 2
stopped at item 3: [Errno 28] No space left on device
```

Now only `write()` calls on the log file's descriptor are traced *and* counted, so `when=3` finally means what we wanted:

```bash
$ cat scoped.strace.log
write(3, "processed item 1\n", 17)      = 17
write(3, "processed item 2\n", 17)      = 17
write(3, "processed item 3\n", 17)      = -1 ENOSPC (No space left on device) (INJECTED)
+++ exited with 1 +++

$ cat progress.log
processed item 1
processed item 2
```

Items 1 and 2 are safely on disk, item 3 was rejected exactly as a real full disk would reject it, and our `except OSError` caught it cleanly. No traceback, no silently corrupted file, just the error message we wrote for this exact situation. That error handling branch just ran for the first time ever.

## 🧫 From watching to asserting

Eyeballing terminal output is fine for a blog post, useless for a test suite. The actual goal was never "watch the failure happen," it's "assert that our error handling does the right thing." So let's turn the manual demo into something that can fail a build:

```python
#!/usr/bin/env python3
"""Assert progress_log's unhappy path: a disk-full write() must be caught,
reported, and must not corrupt entries already on disk. This is the point
of the whole exercise -- not just watching the failure happen, asserting on it."""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def run_with_injected_fault(count, path, when):
    abs_path = os.path.abspath(path)
    return subprocess.run(
        [
            "strace", "-e", "trace=write", "-P", abs_path,
            "-e", f"inject=write:error=ENOSPC:when={when}",
            sys.executable, os.path.join(HERE, "progress_log.py"), str(count), path,
        ],
        capture_output=True, text=True,
    )


def main():
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "progress.log")
        result = run_with_injected_fault(count=5, path=path, when=3)

        assert result.returncode == 1, f"expected exit code 1, got {result.returncode}"
        assert "stopped at item 3" in result.stderr, (
            f"expected a failure message for item 3 on stderr, got: {result.stderr!r}"
        )
        assert "No space left on device" in result.stderr, (
            f"expected ENOSPC in the error message, got: {result.stderr!r}"
        )

        with open(path) as f:
            lines = f.readlines()
        assert len(lines) == 2, f"expected exactly 2 items to survive, found {len(lines)}"

        print("PASS: progress_log detects and reports a failed write(), and stops without corrupting the log")


if __name__ == "__main__":
    main()
```

```bash
$ python3 test_progress_log.py
PASS: progress_log detects and reports a failed write(), and stops without corrupting the log
```

No test framework, no fixtures. `subprocess` and `assert` are enough to shell out to `strace` exactly as we did by hand, and check three things a reviewer would actually ask about: did it exit non-zero, did it say why, and did it leave the file in a consistent state (2 good items, not 3, not garbage). This is the unhappy path test that never existed before today, running against code that never had to prove it worked before today. Wire it into CI (mind the `ptrace` in containers caveat below) and this failure mode stays caught, forever, on every future change to `progress_log.py`.

## 🤨 Why not just mock it?

Fair objection. You could reach for `unittest.mock.patch("builtins.open")`, raise `OSError` yourself, and assert it gets caught. No `strace`, no `subprocess`, no `ptrace` capability needed in CI. Looks simpler, and honestly, it is simpler.

It's also testing something else entirely. Mock the failure and you're really just asserting that your `except OSError` catches an `OSError`, the one you handed it yourself a moment earlier. That's true by construction, and it says nothing about what happens when the *real* `write()` syscall fails, because a mock never goes anywhere near the real IO stack.

That difference isn't theoretical. It already bit us once in this very post. The buffered writer quietly retrying on `close()`, the whole reason `progress_log` opens with `buffering=0`, only shows up when a real `write()` fails for real, inside Python's real buffering layer. Mock `open()` and that layer simply isn't part of the test anymore. The gotcha stays invisible and the bug ships anyway.

Syscall level injection also asks nothing of your code. There's no patch point to design around, and it works exactly the same whether you're poking at a subprocess, a third party library, or a binary you don't even have the source for. Mocking is great for pure logic. It just can't tell you much about how your code behaves at the actual boundary the kernel talks to you through, and that boundary is what this whole series is about.

## ⚠️ A word of caution

Two concrete things to watch for, both of which we just hit ourselves.

Scope your injection deliberately. The unscoped run above didn't fail where we intended, it failed *somewhere real*, just not the somewhere we picked. Run `--inject` against a service that actually matters and an unscoped filter can take down a code path you never meant to touch. Always reach for `-P` (or a narrower `-e trace=`) before pointing this at anything beyond a throwaway test binary.

And `strace` needs `ptrace`, which containers love to block. It has to run as the same user as the target, or hold `CAP_SYS_PTRACE`, and Docker's default seccomp profile denies `ptrace` outright. You'll need `--cap-add=SYS_PTRACE` or `--security-opt seccomp=unconfined` to run any of this inside a default container, which matters a lot if you were hoping to drop this straight into CI.

We'll hit the overhead question head on later in the series, when we compare this against seccomp and eBPF.

## 🏁 Wrap-up

We covered what a syscall actually is, why forcing them to fail on purpose is worth doing, and got our first working fault injection with no injection code of our own to write. strace does the work, `progress_log.py` is just something to point it at. We hit a real gotcha about what "the 3rd call" actually counts, twice, and instead of stopping at "well, it worked when I ran it," turned the whole thing into an assertion that can catch a regression on its own. That was the actual goal from the start: not to watch `write()` fail, but to prove our code handles it when it does.

Next up: we outgrow `strace` and roll our own `ptrace` based tool, which opens the door to faults `--inject` can't do, like a `write()` that "succeeds" but only writes part of the buffer. That chapter will pick whatever target best shows off that mechanism, no assumption that it's the same program as this one.

Full source for this chapter is inlined above. `progress_log.py` and `test_progress_log.py`, unmodified, are what generated every transcript in this post.

## 📚 Credits & further reading

The [`strace(1)` man page](https://man7.org/linux/man-pages/man1/strace.1.html) documents the `--inject`/`-e inject=` flags in full. Dmitry Levin's [FOSDEM 2017 talk on strace fault injection](https://archive.fosdem.org/2017/schedule/event/failing_strace/attachments/slides/1630/export/events/attachments/failing_strace/slides/1630/strace_fosdem2017_ta_slides.pdf) covers the same feature from the maintainer's side, alongside the original [2016 GSoC groundwork](https://lists.strace.io/pipermail/strace-devel/2016-March/004649.html) that started it. And if this scratched an itch, my earlier posts cover similar ground: [Expect the unexpected](https://ilmanzo.github.io/post/faulty_disk_simulation/) looks at device mapper disk faults, and [Fault Injection in Network Namespace and Veth Environments](https://ilmanzo.github.io/post/faulty_network_simulation/) does the same thing with `netem`.

Happy (fault) hacking!
