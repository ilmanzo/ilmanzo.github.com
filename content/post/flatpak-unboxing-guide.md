---
layout: post
title: "Flatpak: unboxing the sandbox"
description: "How to have new apps without letting the dependency mess leak onto your carpet"
categories: linux
tags: [linux, flatpak, security, tutorial, systems, sysadmin]
author: Andrea Manzini
date: 2026-05-03
---

## 📦 That *new package* smell

We’ve all been there: you see a shiny new app on GitHub and you want to "unwrap" it immediately. But in the traditional Linux world, opening a package often feels like opening a box of glitter in your living room—before you know it, dependencies are scattered everywhere, and you're still finding weird library versions in `/usr/lib` three months later.

This is why I've started reaching for the **Flatpak**. It’s like an unboxing experience where the box stays a box. You get all the "goodies" inside, but the mess stays contained. Let's see what happens when we tear off the shrink-wrap.

![unboxing](/img/pexels-borishamer-29202644.jpg)
[Image credits: Boris Hamer](https://www.pexels.com/@314917712/)

## 🐤 Bubblewrap + OSTree: your safety seals

When you open a Flatpak, there are two layers of "packaging" keeping things safe:

1.  **[Bubblewrap](https://github.com/containers/bubblewrap):** Think of this as the clear security tape around the internal components. It uses Linux **namespaces** to make sure the app can see its own files, but can't "leak" out onto your host OS. It’s a sandbox that keeps the app's sticky fingers off your system files.
2.  **[OSTree](https://ostreedev.github.io/ostree/):** This is how the "parts" are stored. It’s like a modular shelf system. If ten different packs need the same "power cord" (runtime), OSTree ensures you only have one physical cord on your shelf. Deduplication: because nobody needs ten copies of the GNOME runtime.

## 👣 Peeking through the wrapping

One of the best parts of a "Pack" is that it comes with a manifest. You don't have to guess what's inside or what it's trying to do. You can peer through the plastic before you even run it.

Let's look at the "Instruction Manual" for Obsidian:

```bash
$ flatpak info --show-metadata md.obsidian.Obsidian
```

Under the `[Context]` header, you’ll see exactly what this app is allowed to touch. If it's asking for `network` and `pulseaudio`, you know it’s going to be talking to the web and making noise. It’s the ultimate "What's in the box?" transparency.

## 🔧 Handling your packages: The CLI toolbox

You don't need a fancy GUI to manage your packs. The command line is faster and gives you more control over the "unboxing."

### The daily routine
| Task | Command |
| :--- | :--- |
| **Search the catalog** | `flatpak search <name>` |
| **Grab a new pack** | `flatpak install flathub <app_id>` |
| **See your shelf** | `flatpak list --app` |
| **Refresh the stock** | `flatpak update` |

### Throwing away the scraps
Sometimes you "open" a few apps and decide you don't like them. If you've uninstalled them but left the extra "packaging" (runtimes) behind, run this to clear the clutter:

```bash
$ flatpak uninstall --unused
```

## 🛠️ DIY: Building your own box

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

## 🎨 Tune the box your way

One of the best things about Flatpak is that the "Instruction Manual" isn't set in stone. If you don't like a permission the developer chose, you can just override it.

### The CLI way
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

### The "undo" button
If you go too far and the app stops working, don't panic. You can always go back to the "factory settings" with a single command:
```bash
$ flatpak override --reset org.some.App
```
### Pro tip: Flatseal
If you prefer a visual dashboard to toggle these switches, check out **[Flatseal](https://github.com/tchx84/Flatseal)**. It’s a Flatpak itself that gives you a clean interface to manage permissions for every app on your system. It's the ultimate "safety inspector" tool.

## 🎁 Extra goodies for curious tinkerers

Since we’re tearing through the packaging, here are three extra things you can do with your Flatpaks that you might not know about:

### 1. The portable "offline" bundle
Ever wanted to give a specific app to a friend who has no internet, or install it on an air-gapped server? You can export an installed app into a single `.flatpak` file:

```bash
$ flatpak create-bundle /path/to/repo my-app.flatpak org.some.App
```
*Now you have a portable, self-contained installer!*

### 2. CLI apps are packs too!
Flatpaks aren't just for heavy GUIs like GIMP or Obsidian. You can find high-performance CLI tools like `neovim`, `ffmpeg`, or `btop` on Flathub. To run them as if they were native, just add an alias to your `.bashrc`:

```bash
alias nvim='flatpak run io.neovim.nvim'
```

### 3. XDG Portal: your polite bridge to host files
Ever wonder how a sandboxed app can "Open a File" without having permission to see your whole drive? That's the **XDG Portal**. 

When you click "Open," the app asks the *Portal service* (which lives on your host) to show a file picker. **You** pick the file, and the Portal hands a temporary "token" to the app for *just that one file*. It’s like a hotel keycard—it opens your room, but it doesn't give you the keys to the whole building.

## 🕰️ Repos, history, and tiny time machines

Flatpak isn't tied to a single "Store." It uses **Remotes**, which are just repositories where packs are stored.

### Adding your sources
Most people just use Flathub, but you can have as many as you want (Beta repos, GNOME nightly, etc.):

```bash
$ flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

### Version time-travel (rollbacks)
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

## 🏁 Wrapping up

Flatpak can turn any workstation from a cluttered workshop into a clean, modular shelf. You can open, test, and discard "packs" of software without ever worrying that a stray `.so` file is going to ruin your day. 

Next time you're about to `sudo apt install` a massive suite of tools, maybe try a Flatpak instead. Keep the mess in the box. Happy Hacking!