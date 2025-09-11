---
layout: post
title: "From QEMU Headache to Headless"
description: "Taming a Command-Line Monster with D"
categories: [programming, testing]
tags: [testing, tutorial, linux, dlang, virtualization, emulation, scripting]
author: Andrea Manzini
date: 2025-09-11

---

## 😸 TL;DR

Being lazy, I made [a tool](https://github.com/ilmanzo/qboot) to run `qcow2` images for my convenience. Feel free to use it if you find useful!

## 📖 The back story

If you've ever typed `qemu-system-x86_64` into your terminal, you know the feeling. A creeping dread. A cold sweat. The QEMU *headache*. It’s that special migraine reserved for developers who know they're about to spend the next ten minutes deciphering their own shell history to remember that one magic flag for networking.

This was my daily reality. My job requires testing software on a whole zoo of Linux versions. I live and breathe `qcow2` images, spinning them up and tearing them down. But every single launch was a fresh new adventure in forgetting flags. Did I add `-cpu host` for performance? Did I remember `-device usb-tablet` so my mouse doesn't look like it's breakdancing in the corner? 🤯

After accidentally saving breaking changes to a pristine base image for the hundredth time because I forgot -snapshot, I had a moment of clarity. A glorious, table-flipping moment. ╯°□°）╯︵ ┻━┻

My problem wasn't QEMU. It was **remembering** QEMU options. The solution was simple: build a tool so I could forget.

## 🥾 A Cure for the Common Command-Line Cold

I needed a wrapper script, a quick boot sidekick. The prescription was clear:

- A Single Pill: One self-contained binary. No side effects, no dependencies, no "make sure you have Python 3.9.x installed."

- Easy to Modify: It had to be readable enough that "Future Me" wouldn't curse "Past Me."

- The Right Tool for the Job: Not too heavy, not too light.

Go, Rust, Python... all great languages. But Go's error handling felt a bit bureaucratic for this task. Rust felt like bringing a tactical nuke to a knife fight. And Python, while lovely, violated my "single pill" rule.

And then, I remembered an old friend: The D Language. 🐉


D might not be the most popular kid on the block, but for projects like this, it's an absolute revelation. It hit every single one of my wishlist items with the elegance of a well-executed magic trick:

- Single Executable? ✅ D compiles to native code. My qboot helper is just one file, ready to rock on any compatible Linux system. Deployment? Solved.

- Linux Love? ✅ D's standard library is robust, and dub (its fantastic package manager) makes cross-distro building a breeze.

- Readability & Power? ✅✅ This is where D truly shines. Its syntax is incredibly clean and familiar if you've ever touched a C-like language (which, let's be honest, most of us have!). But it also packs modern features like powerful metaprogramming, concise array manipulation, and a solid standard library. It's like C++ got a spa day and came back refreshed, ready to work. Plus, its default garbage collector means I don't have to fuss with manual memory management for this kind of task, keeping my brain cycles focused on QEMU, not pointers.

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
$ ./qboot -d my-disk.qcow2 -i
```

My QEMU headache is gone, replaced by the quiet hum of a tool that does exactly what I want.

So if you're tired of the command-line flag dance, maybe it's time to build your own cure. And hey, give D a look while you're at it. It might just be the pragmatic dragon you've been searching for to tame your own command-line beasts! 🐲✨

## 💭 Final Thoughts

Or: Why D Deserves a Second Look (Especially for CLI Tools!)

While D isn't going to replace Python or Go in popularity overnight, it absolutely hits a sweet spot for practical command-line utilities.

- Fast Compilation: D's reference compiler (DMD) is incredibly fast, making the "edit-compile-run" loop delightful.

- Modern Features: It offers powerful language features that make expressive and safe code easy to write, without forcing you into complex paradigms.

- Minimalist & Performant: You get the single-binary advantage of Go and Rust, with excellent runtime performance, but often with less code.

So, the next time you're tired of wrestling with command-line options for your dev tools, or need a quick, performant, and easily deployable utility, give D a whirl. You might just find your own magical sidekick. ✨ It certainly saved my sanity from QEMU Tetris!

Project repository can be found at https://github.com/ilmanzo/qboot . Contributions are welcome!

