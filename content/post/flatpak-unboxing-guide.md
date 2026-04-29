---
layout: post
title: "Flatpak: Unboxing the Sandbox"
description: "How to open new apps without letting the dependency mess leak onto your carpet"
categories: linux
tags: [linux, flatpak, security, tutorial, systems]
author: Andrea Manzini
date: 2026-05-01
---

## 📦 Intro: That New Package Smell

We’ve all been there: you see a shiny new app on GitHub and you want to "unwrap" it immediately. But in the traditional Linux world, opening a package often feels like opening a box of glitter in your living room—before you know it, dependencies are scattered everywhere, and you're still finding weird library versions in `/usr/lib` three months later.

This is why I've started reaching for the **Flatpak**. It’s like an unboxing experience where the box stays a box. You get all the "goodies" inside, but the mess stays contained. Let's see what happens when we tear off the shrink-wrap.

![unboxing](/img/pexels-mrdanny-9418501.jpg)
[Image credits: Mr. Danny](https://www.pexels.com/photo/person-opening-a-cardboard-box-9418501/)

## 🐤 The "Security Tape": Bubblewrap and OSTree

When you open a Flatpak, there are two layers of "packaging" keeping things safe:

1.  **Bubblewrap:** Think of this as the clear security tape around the internal components. It uses Linux **namespaces** to make sure the app can see its own files, but can't "leak" out onto your host OS. It’s a sandbox that keeps the app's sticky fingers off your system files.
2.  **OSTree:** This is how the "parts" are stored. It’s like a modular shelf system. If ten different packs need the same "power cord" (runtime), OSTree ensures you only have one physical cord on your shelf. Deduplication: because nobody needs ten copies of the GNOME runtime.

## 👣 Peeking Through the Wrapping

One of the best parts of a "Pack" is that it comes with a manifest. You don't have to guess what's inside or what it's trying to do. You can peer through the plastic before you even run it.

Let's look at the "Instruction Manual" for Obsidian:

```bash
$ flatpak info --show-metadata md.obsidian.Obsidian
```

Under the `[Context]` header, you’ll see exactly what this app is allowed to touch. If it's asking for `network` and `pulseaudio`, you know it’s going to be talking to the web and making noise. It’s the ultimate "What's in the box?" transparency.

## 🔧 Handling your Packages: The CLI Toolbox

You don't need a fancy GUI to manage your packs. The command line is faster and gives you more control over the "unboxing."

### The Daily Routine
| Task | Command |
| :--- | :--- |
| **Search the catalog** | `flatpak search <name>` |
| **Grab a new pack** | `flatpak install flathub <app_id>` |
| **See your shelf** | `flatpak list --app` |
| **Refresh the stock** | `flatpak update` |

### Throwing away the Scraps
Sometimes you "open" a few apps and decide you don't like them. If you've uninstalled them but left the extra "packaging" (runtimes) behind, run this to clear the clutter:

```bash
$ flatpak uninstall --unused
```

## 🛠️ DIY: Building your own Box

Ever wondered how hard it is to put your own script into a "box"? It’s surprisingly simple. All you need is a manifest (the blueprints) and your code.

Let's create a "Hello Flatpak" app. First, create a script named `hello.sh`:

```bash
#!/bin/sh
echo "Hello from inside the box! I can't see your secrets!"
```

Now, create a manifest file named `org.test.Hello.yaml`:

```yaml
app-id: org.test.Hello
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: hello.sh
modules:
  - name: hello
    buildsystem: simple
    build-commands:
      - install -D hello.sh /app/bin/hello.sh
    sources:
      - type: file
        path: hello.sh
```

To build and "box it up," you’ll need `flatpak-builder`. Run these two commands:

```bash
# Build the app into a folder named 'build-dir'
$ flatpak-builder --user --install --force-clean build-dir org.test.Hello.yaml

# Run your new creation
$ flatpak run org.test.Hello
```

Just like that, you’ve created a sandboxed app. It has its own `/app` prefix and can't touch your home directory unless you explicitly add a `finish-args` section to the manifest. 

## 🎨 Customizing the Box: Permission Overrides

One of the best things about Flatpak is that the "Instruction Manual" isn't set in stone. If you don't like a permission the developer chose, you can just override it.

### The CLI Way
The `flatpak override` command is your best friend here. It allows you to "re-box" an app on the fly.

*   **Cutting the cord:** Don't trust an app? Block its internet access:
    ```bash
    $ flatpak override --nosocket=network org.some.App
    ```
*   **Targeted Folder Access:** Need your editor to see your external SSD?
    ```bash
    $ flatpak override --filesystem=/media/external_drive org.some.IDE
    ```
*   **Injecting Environment Variables:** Want to force a specific theme or debug mode?
    ```bash
    $ flatpak override --env=DEBUG=1 org.some.App
    ```

### The "Undo" Button
If you go too far and the app stops working, don't panic. You can always go back to the "factory settings" with a single command:
```bash
$ flatpak override --reset org.some.App
```
### Pro Tip: Flatseal
If you prefer a visual dashboard to toggle these switches, check out **Flatseal**. It’s a Flatpak itself that gives you a clean interface to manage permissions for every app on your system. It's the ultimate "safety inspector" tool.

## 🎁 The Bonus Pack: More Cool Stuff

Since we’re tearing through the packaging, here are three extra things you can do with your Flatpaks that you might not know about:

### 1. The Portable "Offline" Bundle
Ever wanted to give a specific app to a friend who has no internet, or install it on an air-gapped server? You can export an installed app into a single `.flatpak` file:

```bash
$ flatpak create-bundle /path/to/repo my-app.flatpak org.some.App
```
*Now you have a portable, self-contained installer!*

### 2. CLI Apps are Packs too!
Flatpaks aren't just for heavy GUIs like GIMP or Obsidian. You can find high-performance CLI tools like `neovim`, `ffmpeg`, or `btop` on Flathub. To run them as if they were native, just add an alias to your `.bashrc`:

```bash
alias nvim='flatpak run io.neovim.nvim'
```

### 3. The XDG Portal: The Controlled Bridge
Ever wonder how a sandboxed app can "Open a File" without having permission to see your whole drive? That's the **XDG Portal**. 

When you click "Open," the app asks the *Portal service* (which lives on your host) to show a file picker. **You** pick the file, and the Portal hands a temporary "token" to the app for *just that one file*. It’s like a hotel keycard—it opens your room, but it doesn't give you the keys to the whole building.

## 🕰️ The Archive: Repositories and Time Travel

Flatpak isn't tied to a single "Store." It uses **Remotes**, which are just repositories where packs are stored.

### Adding your Sources
Most people just use Flathub, but you can have as many as you want (Beta repos, GNOME nightly, etc.):

```bash
$ flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

### Version Time-Travel (Rollbacks)
This is a killer feature. Because Flatpak uses OSTree, it keeps a history of your updates. If a new version of an app breaks your workflow, you can literally travel back in time.

1.  **See the history:**
    ```bash
    $ flatpak remote-info --log flathub org.some.App
    ```
2.  **Roll back to a specific commit:**
    ```bash
    $ flatpak update --commit=abcdef12345 org.some.App
    ```
*No more "waiting for the dev to fix the bug"—you just go back to the version that worked.*

## 🏁 Conclusion

## 🎩 The Hacker's Toolbox: Advanced Hacks

Since you’ve read this far, you’re clearly not a casual user. Here are three "power moves" to make Flatpaks feel like a native part of your system.

### 1. The "Theme Fix" (Visual Harmony)
One common gripe is that Flatpaks don't always pick up your custom GTK or Icon themes. You can "force" them to see your host's config:

```bash
$ flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro
```
*This allows the sandbox to read your theme settings without giving it permission to change them.*

### 2. Sharing the SSH Agent (Dev Power Move)
If you're using a flatpaked IDE (like VS Code or IntelliJ) and need to push code to GitHub using your host's SSH keys, you need to "bridge" the SSH socket:

```bash
$ flatpak override --user --filesystem=$SSH_AUTH_SOCK --env=SSH_AUTH_SOCK=$SSH_AUTH_SOCK org.some.IDE
```
*Now your sandboxed IDE can use your host’s encrypted keys without you having to copy them into the sandbox (which you should never do!).*

### 3. The "Internal Shell" (Debugging)
Ever wonder why an app is crashing or where it’s storing its config? You can drop into a shell **inside** the app's specific sandbox:

```bash
$ flatpak run --command=sh org.some.App
```
*Once inside, you can explore the `/app` and `/var` folders to see exactly how the "internal" world looks. It’s like being a tiny explorer inside the box.*

### 4. The Escape Hatch
Sometimes you’re working inside the pack, but you need to grab a tool from the host's garage. You can "spawn" a process back onto the host:

```bash
$ flatpak-spawn --host git commit -m "escaped the sandbox"
```

### Custom Compartments
You can "tape" a specific folder from your host onto the side of the sandbox. Great for letting a flatpaked IDE see only one specific project folder:

```bash
$ flatpak override --filesystem=~/projects/secret-sauce:rw org.some.IDE
```
*(The `:rw` means it can write back to the host. Use `:ro` if you don't trust the app with your precious code!)*

## 🏁 Conclusion

Flatpak has turned my workstation from a cluttered workshop into a clean, modular shelf. I can open, test, and discard "packs" of software without ever worrying that a stray `.so` file is going to ruin my day. 

Next time you're about to `sudo apt install` a massive suite of tools, maybe try a Flatpak instead. Keep the mess in the box. Happy Hacking!
