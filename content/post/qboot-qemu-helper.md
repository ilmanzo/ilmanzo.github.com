---
layout: post
title: "From QEMU Headache to Headless"
description: "Taming a Command-Line Monster"
categories: [programming, testing]
tags: [testing, tutorial, linux, dlang, golang, virtualization, emulation, scripting]
author: Andrea Manzini
date: 2025-09-28

---

## 😸 TL;DR

Being lazy, I made [a tool](https://github.com/ilmanzo/qboot) to run `qcow2` images for my convenience. It now supports x86_64, aarch64, s390x, and ppc64le. Feel free to use it if you find it useful! 
## 📖 The back story

If you've ever typed `qemu-system-x86_64` into your terminal, you know the feeling. A creeping dread. A cold sweat. The QEMU *headache*. It’s that special migraine reserved for developers who know they're about to spend the next ten minutes deciphering their own shell history to remember that one magic flag for networking.

This was my daily reality. My job requires testing software on a whole zoo of Linux versions across architectures like **x86_64**, **aarch64**, **s390x**, and **ppc64le**. I live and breathe `qcow2` images, spinning them up and tearing them down. But every single launch was a fresh new adventure in forgetting flags. Did I add `-cpu host` for performance? Did I remember `-device usb-tablet` so my mouse doesn't look like it's breakdancing in the corner? 🤯

After accidentally saving breaking changes to a pristine base image for the hundredth time because I forgot -snapshot, I had a moment of clarity. A glorious, table-flipping moment. ╯°□°）╯︵ ┻━┻

My problem wasn't QEMU. It was **remembering** QEMU options. The solution was simple: build a tool so I could forget.

## 🥾 A Cure for the Common Command-Line Cold

As the project grew, so did my needs. I needed a wrapper script, a quick boot sidekick that was robust, portable, and easy to maintain. The prescription was clear:

A Single Pill: One self-contained binary. No side effects, no dependencies, no “make sure you have Python 3.9.x installed.”

Easy to Modify: It had to be readable enough that “Future Me” wouldn’t curse “Past Me.”

The Right Tool for the Job: Powerful enough to handle complexity, but simple enough for a small side project.

Initially, I wrote this tool in D, but as I looked to the future of the project, I knew I needed something else. So I decided to rewrite it in Go. 🐹

Go wasn't just the popular kid on the block; for a project like this, it was the perfect evolution. It hit every single one of my wishlist items with pragmatic grace:

Single Executable? ✅ Go compiles to a static native binary by default. My qboot helper is just one file, ready to rock on any Linux system. Deployment? Solved.

Linux Love? ✅ Go’s cross-compilation is legendary. Building for aarch64, s390x, and ppc64le from a single machine is trivial, not a weekend-long project.

Readability & Power? ✅✅ This is where Go excels for CLI tools. Its syntax is clean, simple, and incredibly easy to pick up. The robust standard library has everything you need for files, commands, and networking. Plus, features like goroutines and channels, while maybe overkill for this tool today, give me room to grow without over-engineering. It’s all the power I need with none of the fuss.


## 💆 Headless by Default

I started crafting the [qboot](https://github.com/ilmanzo/qboot) tool, defining a `VirtualMachine` struct to hold all the options. This "object-oriented" approach meant my VM's configuration was neatly separated from the complex logic of building QEMU commands. No more spaghetti code! 

My `qboot` tool was designed around my two main workflows:

🤖 Headless Mode (The Default): This is for my daily testing grind. It runs with `-nographic` and, most importantly, uses a `-snapshot` so my base images are untouched. It's fast, it's clean, and it's as disposable as a paper cup. This mode is the reason I can now sleep at night.

🧑‍💻 Interactive Mode (`-i` for "I need to see!"): This is for manual surgery. When I need to actually log in, create a user, or install something, this mode pops up a GUI, enables a non-possessed mouse, and disables snapshots so my changes are saved.

To make it even more brainless, `qboot` auto-creates a `config.json` file in `~/.config/qboot/` on its first run. I just set my default CPU and RAM in there once, and I'm done. Forever.

## ♻️ The Glorious Result

My workflow has been transformed.

Before `qboot` (The Headache):
```bash
$ qemu-system-x86_64 -m 8G -cpu host \
   -enable-kvm -drive file=... wait, what was the syntax for virtio again? *opens Google*
```

After qboot (Headless Bliss):
```bash
$ ./qboot -d my-disk.qcow2
```

That's it. It just works. If I need to do some setup first:
```bash
$ ./qboot -d my-disk.qcow2 -w
```

My QEMU headache is gone, replaced by the quiet hum of a tool that does exactly what I want.


## 💭 Final Thoughts

While Go has already won the popularity contest, it's worth repeating why it's a perfect fit for practical command-line utilities.

- Fast Compilation & Execution: Go compiles incredibly fast, making the “edit-compile-run” loop a joy. The resulting binary is performant, starting instantly.

- Simplicity is Genius: It offers a small, focused set of features that are incredibly effective for building reliable and maintainable software. You spend your time solving problems, not fighting the language.

- Deploy Anywhere: The ability to cross-compile to a single, dependency-free binary is a superpower. Sharing your tool with others or deploying it to different machines is effortless.

So, the next time you’re tired of wrestling with command-line options for your dev tools, or need a quick, performant, and easily deployable utility, give Go a whirl. You might just find your own gopher sidekick. ✨ It certainly saved my sanity from QEMU Tetris!

Project repository can be found at https://github.com/ilmanzo/qboot . Contributions are welcome!
