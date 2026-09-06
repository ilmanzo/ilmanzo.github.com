---
layout: post
title: "A presence-aware break reminder"
description: "An old Intel Atom netbook turned into a desk monitor that reminds you to take breaks, with motion, espeak-ng and a small Nim service."
categories: [programming, hacking]
tags: [nim, linux, void, hacking, diy, retro, hardware, systems]
author: Andrea Manzini
date: 2026-09-06
---

Most break reminders run on a plain clock. You set a 50 minute timer and then you walk away for 30 of those minutes to get a coffee. The timer still fires the moment it runs out. It does not know that you just sat back down.

I already wear a smartwatch. It taps my wrist after I sit for too long, which helps, but it measures the wrong thing. It watches my wrist, not my desk. A few arm movements are enough to convince it that I got up. In the meantime I am still in the same chair, in front of the same screen.

I am also the kind of person who concentrates hard enough to lose track of time. Eyestrain is usually the first sign that I went too far.

So I wanted something that watches the desk instead. On that desk sits an old 2009 piece of e-waste: a **Samsung N130 netbook** with a single core Intel Atom processor and 1GB of RAM. It runs [**Void Linux**](https://voidlinux.org/), and it is the same machine I [turned into a basement WiFi router]({{< ref "repurpose_old_netbook_as_wifi_repeater" >}}) a few months ago.

I made it a desk sentinel. It checks whether I am really sitting in front of the workstation. It counts work time only while I am there, and it speaks up once I stay too long.

![taking a break](/img/pixabay-bananayota-5956897.jpg)
Image credits to: [Bananayota](https://pixabay.com/users/bananayota-20054590/), found on [Pixabay](https://pixabay.com/photos/person-sit-bench-alone-sitting-5956897/)

## TL;DR

* An old Samsung N130 netbook running Void Linux now works as a desk sentinel.
* [`motion`](https://motion-project.github.io/) watches the built-in webcam. On every start and stop of movement it writes `active` or `idle` into a plain state file.
* A small Nim daemon reads that file and tracks continuous desk time with a live one line progress bar. Once the limit is reached, it calls `espeak-ng` and `wall`. An absence under 5 minutes does not reset the clock.
* Nothing is recorded. The video feed never leaves the netbook and no frame is written to disk.
* The daemon runs as an unprivileged supervised `runit` service. It costs 0.01% of one core and 2 MB of RAM. `motion` is the real cost on this hardware.
* On the way I found and fixed a shell injection bug in the alarm code, a broken `motion.conf` quoting bug and two display bugs. Details below.

<!--more-->

---

## 🧠 The idea: passive webcam presence tracking

Camera based presence trackers usually load a face detection or object detection model, for example an OpenCV neural network or a Haar cascade. That is a lot of work for a 1.6GHz single core Atom. It is also more than I need. I do not care who is at the desk. I only need to know whether something in the frame moves.

So instead of writing a camera loop, I used an existing C daemon that already does exactly that: [**`motion`**](https://motion-project.github.io/).

`motion` detects movement on `/dev/video0` by comparing consecutive frames. It is cheap compared to a detection model. It can also run a command at the moment it decides that motion started or stopped.

### On privacy

This matters to me, so it is worth stating plainly: the setup records nothing. `motion` can save pictures and videos, but here every output option is off. The frames are compared in memory and then dropped. No image reaches the disk, no image leaves the machine, and the netbook has no cloud account attached to it.

Only one thing crosses the boundary between `motion` and the rest of the system: a single word in a text file, either `active` or `idle`. I do not want to hand a camera in my work room to a third party. Here there is no third party to hand it to.

---

## 🔌 1. Configuring `motion` to detect presence

`motion` has event hooks. I use two of them:

*   `on_event_start`: runs on the first detected motion, which means somebody just sat down at the desk.
*   `on_event_end`: runs after `event_gap` seconds without motion.

Rather than spawn a shell script on every frame, I let `motion` write one word into `/tmp/presence_state`.

In `/home/andrea/webcam-capture/config/motion.conf`:
```text
event_gap 60

on_event_start echo active > /tmp/presence_state
on_event_end echo idle > /tmp/presence_state
```

Note that there are no quotes around the shell commands. My first draft wrapped them in double quotes because it looked tidier, and it was wrong. `motion` passes the whole line to `/bin/sh -c` as it is. With an outer pair of quotes the `>` stops being a redirection and becomes literal text. The command then fails with "not found" every single time. I only noticed because the state file never changed. I had wired presence detection to a command that can never run.

`event_gap 60` means that `motion` tolerates a full minute of stillness before it decides that you are gone. That is useful, because you do not want the state to flip to `idle` every time you pause to think. The Nim daemon below holds a second and independent threshold of 5 minutes. That one decides whether an absence counts as a real break and resets the work clock. Short pauses survive both thresholds.

Void Linux mounts `/tmp/` as a **`tmpfs`**, an in memory filesystem, so reading and writing `/tmp/presence_state` never touches the disk.

`motion` runs as its own supervised service, pointed at that configuration.

`/etc/sv/webcam-motion/run`:
```bash
#!/bin/sh
exec 2>&1
exec motion -n -c /home/andrea/webcam-capture/config/motion.conf
```

---

## 👑 2. The Nim state monitor, timer and live countdown

`motion` handles video capture and frame analysis in C, so the daemon only has to read `/tmp/presence_state` every few seconds and keep a timer.

I wrote it in [**Nim**](https://nim-lang.org/), which compiles to native code with a small runtime. That matters on a 1.6GHz single core Atom.

The program takes three optional command line arguments:

1.  **Work limit in minutes:** active minutes before the alarm, 60 by default.
2.  **Language code:** the language passed to `espeak-ng`, for example `it` or `en`, `it` by default.
3.  **Custom message:** an optional string to speak. If it is empty, the daemon builds a default message in the chosen language.

### Live display and shared countdown

Instead of printing a fresh line every 10 seconds, the status line rewrites itself in place with `\r`. A small progress bar shows how much of the work limit is gone:

```text
[##########----------] Active 0m 30s | Remaining 0m 30s
```

The remaining time also goes into `/tmp/break_countdown` on every tick. That file lives on `tmpfs` too, so it stays cheap. You can pull it into a tmux status bar, a shell prompt or a small terminal window:
```bash
watch -n 10 cat /tmp/break_countdown
```

### Installing the speech synthesizer

```bash
sudo xbps-install -S espeak-ng
```

### The Nim code (`break_reminder.nim`)

```nim
import std/[os, osproc, strformat, strutils]

const
  StateFile = "/tmp/presence_state"
  CountdownFile = "/tmp/break_countdown"
  TickSeconds = 10
  BreakLimit = 5 * 60 ## minimum absence (seconds) that counts as "took a break"
  BarWidth = 20

func formatTime(seconds: int): string =
  fmt"{seconds div 60}m {seconds mod 60:02}s"

func progressBar(done, total: int): string =
  let filled = clamp((done * BarWidth) div max(total, 1), 0, BarWidth)
  "[" & repeat('#', filled) & repeat('-', BarWidth - filled) & "]"

proc presenceState(): string =
  try: readFile(StateFile).strip()
  except IOError: "idle"

proc writeCountdown(text: string) =
  try: writeFile(CountdownFile, text & "\n")
  except IOError: discard

proc showStatus(line: string) =
  stdout.write "\r" & alignLeft(line, 70)
  stdout.flushFile()

proc speak(lang, text: string) =
  discard execProcess("espeak-ng", args = ["-v", lang, text], options = {poUsePath})

proc triggerAlarm(minutes: int, lang, customMsg: string) =
  echo fmt"BREAK TIME LIMIT REACHED ({minutes} minutes)!"
  let text =
    if customMsg.len > 0: customMsg
    elif lang == "it": fmt"Andrea, fai una pausa! Hai lavorato per {minutes} minuti."
    else: fmt"Andrea, please take a break! You have been working for {minutes} minutes."
  speak(lang, text)
  discard execProcess("wall", args = [fmt"TAKE A BREAK NOW! You have been active for {minutes} minutes."], options = {poUsePath})

proc parseMinutes(s: string): int =
  try: parseInt(s)
  except ValueError: 60

proc paramOrDefault(idx: int, default: string): string =
  if paramCount() >= idx and paramStr(idx).len > 0: paramStr(idx) else: default

proc main =
  let workLimitMinutes = if paramCount() >= 1: parseMinutes(paramStr(1)) else: 60
  let lang = paramOrDefault(2, "it")
  let customMsg = if paramCount() >= 3: paramStr(3) else: ""
  let workLimitSeconds = workLimitMinutes * 60

  echo "Presence-Aware Break Reminder started (Void Linux, motion-integrated)."
  echo fmt"Work limit: {workLimitMinutes}m | Language: {lang}"
  if customMsg.len > 0: echo fmt"Custom message: {customMsg}"

  var presentSeconds, absentSeconds = 0

  while true:
    sleep(TickSeconds * 1000)
    case presenceState()
    of "active":
      presentSeconds += TickSeconds
      absentSeconds = 0
      let remaining = max(0, workLimitSeconds - presentSeconds)
      showStatus fmt"{progressBar(presentSeconds, workLimitSeconds)} Active {formatTime(presentSeconds)} | Remaining {formatTime(remaining)}"
      writeCountdown(formatTime(remaining))
    else:
      absentSeconds += TickSeconds
      let remaining = max(0, workLimitSeconds - presentSeconds)
      if absentSeconds >= BreakLimit and presentSeconds > 0:
        stdout.write "\n"
        echo "Away for 5+ minutes: work clock reset."
        presentSeconds = 0
        writeCountdown("0m 00s (reset)")
      else:
        showStatus fmt"{progressBar(presentSeconds, workLimitSeconds)} Away, countdown paused: {formatTime(remaining)}"
        writeCountdown(fmt"{formatTime(remaining)} (paused)")

    if presentSeconds >= workLimitSeconds:
      stdout.write "\n"
      triggerAlarm(workLimitMinutes, lang, customMsg)
      presentSeconds = 0
      writeCountdown("0m 00s (alarm reset)")

main()
```

That listing is the part of the project I enjoy most. Nim uses significant indentation, no braces and no semicolons. Type inference keeps `let` and `var` declarations short. If you read Python, you can read the loop above without learning anything new first.

Underneath, the resemblance stops. Nim is statically typed and compiles ahead of time through a C backend. The result is a plain ELF binary, around 70KB once the symbols are stripped. There is no interpreter to install on the netbook, no virtual environment and no package tree to keep in sync. I copy one file over `scp` and `runit` starts it.

The same daemon in Python works just as well. It also drags in the CPython runtime and holds tens of megabytes of RAM instead of two. On a machine with 975 MB of it, that is a real difference.

### What it looks like when it runs

Here is the daemon running end to end on the netbook, with the limit set to 1 minute for the demo (`break_reminder 1 en`). In a real terminal every bracketed line overwrites the previous one through `\r`. They are split one per line below only so you can read them:

```text
Presence-Aware Break Reminder started (Void Linux, motion-integrated).
Work limit: 1m | Language: en
[###-----------------] Active 0m 10s | Remaining 0m 50s
[######--------------] Active 0m 20s | Remaining 0m 40s
[##########----------] Active 0m 30s | Remaining 0m 30s
[#############-------] Active 0m 40s | Remaining 0m 20s
[################----] Active 0m 50s | Remaining 0m 10s
[####################] Active 1m 00s | Remaining 0m 00s
BREAK TIME LIMIT REACHED (1 minutes)!
```

### A note on the custom message argument

`triggerAlarm` builds the `espeak-ng` and `wall` calls with `execProcess(..., args = [...])` instead of a concatenated shell string. That is not a matter of style. An earlier draft built the command as `"espeak-ng -v " & lang & " \"" & text & "\""` and ran it through a shell, which is a plain injection hole. A custom message like `foo"; rm -rf ~ #` escapes the quotes and runs arbitrary commands. Passing the arguments as an array skips the shell, so nothing is left to escape.

I tested this with a message that carried exactly that kind of payload. No file appeared. Instead `espeak-ng` read the whole exploit attempt out loud, word by word, quotes and semicolons included. That is the proof I wanted.

The first attempt at the fix uncovered a second bug. By default `execProcess` evaluates the command through a shell, so an `args` array with the default options fails an assertion at runtime. The fix is to pass `options = {poUsePath}`, which drops the shell.

Two smaller bugs appeared only after the service ran for a while. The countdown lost its column alignment whenever the seconds rolled over to zero, so `12m 0s` sat next to `12m 30s`. An empty language argument from the service script also blanked the configured language instead of falling back to the default. Both are one line fixes: zero pad the seconds with `{seconds mod 60:02}`, and ignore empty arguments in `paramOrDefault`.

---

## 🐧 3. Under the hood: the Void Linux `runit` supervision model

Void Linux uses **`runit`** as its init and service supervisor instead of systemd. It is fast, predictable and small.

The service lifecycle uses three directories:

1.  **The registry (`/etc/sv/`):** every available service. Each one is a folder, for example `/etc/sv/break-reminder/`, holding an executable script named **`run`**.
2.  **The active registry (`/var/service/`):** symlinks to folders in `/etc/sv/`. A symlink here means the service is enabled. Remove it and the service is disabled.
3.  **The supervisor:** `runsvdir` watches `/var/service/`. When it sees a new symlink, it forks a dedicated `runsv` process for that service.

Once `runsv` runs the `break-reminder` service, it has one job: keep the daemon alive. If the daemon crashes or gets killed, `runsv` restarts it right away.

---

## 🛠️ 4. Setting up the supervised service

Compile in release mode, optimized for size, then strip the debug symbols with the standard `strip` utility:
```bash
nim c -d:release --opt:size break_reminder.nim
strip --strip-all break_reminder
ls -l break_reminder
```
```text
-rwxrwxr-x 1 andrea andrea 71712 Sep  5 18:14 break_reminder
```

About 70KB, which is small enough to forget about.

### Step 1: create the registry folder
```bash
sudo mkdir -p /etc/sv/break-reminder
```

### Step 2: write the `conf` and `run` scripts

Void service scripts, `sshd` included, keep their configuration in a separate `conf` file. The `run` script sources it first.

`/etc/sv/break-reminder/conf`:
```bash
LIMIT_MINUTES=60
LANGUAGE=it
CUSTOM_MESSAGE=
```

`/etc/sv/break-reminder/run`:
```bash
#!/bin/sh
exec 2>&1
[ -r conf ] && . ./conf
exec chpst -u andrea /home/andrea/bin/break_reminder "${LIMIT_MINUTES:-60}" "${LANGUAGE:-it}" "${CUSTOM_MESSAGE:-}"
```

Two details are worth calling out:

1.  **`chpst -u andrea`:** `runsv` starts services as root by default. This daemon only reads and writes files under `/tmp` and calls `espeak-ng` and `wall`. Both work fine as a regular user, because my account is in the `audio` group. There is no reason to run it as root, so `chpst` drops the privileges before `exec`.
2.  **`exec`:** it replaces the shell process with the compiled binary instead of running it as a child. That way `runsv` supervises the daemon directly, not a shell wrapper around it.

### Step 3: make the script executable
```bash
sudo chmod +x /etc/sv/break-reminder/run
```

### Step 4: symlink and activate
```bash
sudo ln -s /etc/sv/break-reminder /var/service/
```

`runsvdir` picks up the new symlink and starts the service.

---

## 🎛️ Managing the service

```bash
sudo sv status break-reminder
sudo sv stop break-reminder
sudo sv start break-reminder
```

---

## 📏 Real resource measurements

Numbers in a post like this are usually guessed. I sampled the running processes on the netbook instead. CPU time comes from the `utime` and `stime` fields of `/proc/PID/stat`, at 100 ticks per second. Resident memory comes from `VmRSS`.

| Process | RSS | CPU |
|---|---|---|
| `break_reminder` | 2.0 MB | 0.01% of one core |
| `motion` | 40.4 MB | 13.6% of one core |

The Nim daemon burned 3 ticks over a 300 second window. That is 30 milliseconds of CPU in five minutes, which works out to 0.01% of one core. It is small, but it is not zero, so I print the real figure instead of rounding it away.

`motion` is the actual cost here. It burned 1632 ticks over a 120 second window, so 16.3 seconds of CPU in two minutes. Decoding a 640x480 feed at 10fps on a single Atom core is not free.

### What the whole system uses

The more interesting number is not the daemon. It is how little the rest of the machine needs:

```text
               total        used        free      shared  buff/cache   available
Mem:             975         110          22           0         866         864
```

975 MB is what the firmware leaves to Linux out of the nominal gigabyte. With everything running, including `motion`, the break reminder, `sshd` and about 130 processes, the machine uses 110 MB. Subtract the 40 MB that `motion` holds, and the base system sits near 70 MB.

That leaves 864 MB available, close to 89% of the installed RAM, on hardware sold in 2009. There is no desktop environment, no display manager and no systemd here. Void Linux with `runit` and a text console is the reason a 1GB machine still feels roomy.

---

## 📊 Conclusion

This is a quality of life and health project before it is a tinkering project. When I am deep in a problem, eyestrain and lost hours creep up on me. Now something other than my own judgment keeps score. Unlike the smartwatch on my wrist, it cannot be fooled by me fidgeting in the chair.

The parts are all standard Void Linux components: `espeak-ng`, `runit`, `tmpfs` and the event hooks that `motion` already ships. On top of them sits a stripped 70KB Nim binary. `motion` is the heavy tenant, and the netbook now does this job instead of serving as my basement WiFi router. For a machine written off as obsolete more than a decade ago, that is a decent second career.
