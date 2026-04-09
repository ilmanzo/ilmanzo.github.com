---
title: "Landlock idiomatic sandboxing in Nim"
description: "Harden linux programs using Linux Landlock"
date: 2026-04-09
tags: ["linux", "kernel", "LSM", "security", "nim", "systems-programming", "landlock"]
categories: ["Tutorials"]
author: "Andrea Manzini"
---

# 👋 Intro

If you have ever spent time hardening Linux applications, you probably know the frustration of the **all-or-nothing** permission model. In the standard Linux environment, once a process starts running, it usually has *far more* filesystem access than it actually needs. While we have tools like `seccomp`, `chroot`, or heavy-duty modules like **SELinux** and **AppArmor**, they often feel too complex for simple, application-level sandboxing.

**Landlock** changes this. Since its merge into the Linux kernel in version **5.13**, it has become a game-changer for developers. It allows a process to restrict itself *without requiring root privileges*, moving security away from global system policies and directly into your application code.

![landlock](/img/landlock.jpg)

# ⏳ The Evolution of Landlock

Landlock is a maturing API that has evolved significantly. The kernel uses **ABI versions** to signal which features are available on a specific system. This versioning is crucial because it allows your sandbox to *degrade gracefully* on older kernels while still providing the best security possible on modern ones.

The journey began with **ABI v1** in Kernel 5.13, which focused on basic filesystem rights like reading and writing. As the project matured, **version 2** added support for file reparenting, and **version 3** introduced explicit control over file truncation. More recently, **version 4** brought TCP network support, followed by `ioctl` control in **version 5** and IPC scoping in **version 6**. The latest milestone, **version 8**, introduced `TSYNC`, which allows for *atomic security enforcement* across all threads in a process.

For a complete and up-to-date list of these features, you can always check the [Official Landlock Userspace API Documentation](https://docs.kernel.org/userspace-api/landlock.html) or visit the project homepage at [landlock.io](https://landlock.io/).

# 🏗️ Understanding the Architecture

Unlike traditional security modules that are managed by system administrators, Landlock is designed for **application developers**. It is completely *unprivileged*, meaning any process can start a sandbox without needing `sudo` or special capabilities. 

The system is also *stackable*. You can apply multiple layers of rules, where each new ruleset further restricts the process. Once a restriction is applied, it **cannot be relaxed**, and every child process spawned by the application is automatically born into that same sandbox. Most importantly, Landlock is **object-based**. It restricts access based on the internal kernel representation of a file, its `inode`, rather than just its name. This makes it naturally immune to common tricks like *symlink attacks* or *path traversal*.

The operational workflow follows a simple three-step pattern where you first **define** a ruleset of handled operations, then **bind** specific filesystem paths or network ports to those rights, and finally **commit** the restrictions to the current process.

<div style="text-align: center;">
  <img src="/img/real_padlock.jpg" alt="Padlock representing Security" width="200" />
  <p style="font-size: 0.8em; color: gray;"><em>Image from <a href="https://commons.wikimedia.org/wiki/File:Padlock.jpg">Wikimedia Commons</a> (Public Domain)</em></p>
</div>

# ⚙️ The Kernel Interface

Under the hood, Landlock is managed through three primary syscalls. First, `landlock_create_ruleset` initializes a new security ruleset where you specify which operations you want to manage. Any operation you do not specify remains *unrestricted*.

Next, you use `landlock_add_rule` to grant specific permissions to directories or ports. Currently, this primarily uses the `LANDLOCK_RULE_PATH_BENEATH` type to grant access to a specific directory tree. Finally, `landlock_restrict_self` applies the ruleset to the current process. Before this call, you must ensure that `PR_SET_NO_NEW_PRIVS` is set via `prctl` to prevent the process from gaining privileges that could bypass the sandbox.

# 🛡️ Practical Attack Mitigation

To see the value of this approach, consider a standard **path traversal attack** where an attacker tries to read `/etc/shadow` using `../` sequences. Because Landlock enforces security at the kernel `inode` level, these name-based tricks simply fail. If the file is not in your ruleset, the kernel returns a **Permission Denied** error at the very moment the file is opened.

This protection extends to network and IPC as well. With **network access control**, a compromised process can be blocked from connecting to external command-and-control servers. By enabling **IPC scoping**, you can prevent a process from sending signals like `SIGKILL` to any `PID` that is not part of its own restricted security domain.

Beyond these basic examples, Landlock provides robust defense against several other common attack vectors:

*   **Ransomware and Mass File Encryption:** By *strictly limiting* write access to only the necessary directories (such as a temporary folder or a specific data directory) and leaving the rest of the filesystem read-only or inaccessible, ransomware is structurally prevented from modifying or encrypting user files.
    *   *Example:* A PDF reader sandboxed with Landlock only has read access to `/home/user/Documents` and *no write access* anywhere else. If the reader is compromised by a malicious PDF containing ransomware, it simply cannot encrypt your files.
*   **Supply Chain Attacks:** Modern applications rely heavily on third-party dependencies. If a malicious update in a library attempts to harvest SSH keys or establish unauthorized outbound network connections, Landlock will **block** the operation because the application's sandbox explicitly forbids it.
    *   *Example:* A build script restricted by Landlock to only read `./src` and write to `./dist`. If a compromised package tries to read `~/.ssh/id_rsa` and open a network connection to send it to an attacker, Landlock blocks both actions.
*   **Data Exfiltration:** By restricting read access to sensitive locations (like `~/.ssh`, `~/.aws`, or `/etc/shadow`) and locking down network access, attackers who gain arbitrary code execution are unable to steal and transmit sensitive data.
    *   *Example:* A web server only needs access to `/var/www/html`. If an attacker exploits a **Local File Inclusion (LFI)** vulnerability to try and read `/etc/passwd` or `/etc/shadow`, the kernel denies the read.
*   **Privilege Escalation:** Because Landlock rulesets are inherited by all child processes and require the `PR_SET_NO_NEW_PRIVS` flag, an attacker cannot bypass the sandbox by executing **`SUID` binaries**. The child process remains constrained by the *exact same rules* as the parent.
    *   *Example:* Even if an attacker finds a way to execute `sudo` or another `SUID` root binary from within the sandbox, the `PR_SET_NO_NEW_PRIVS` flag ensures the process does not actually elevate privileges, rendering the exploit useless.
*   **Information Disclosure and System Manipulation:** Pseudo-filesystems like `/proc` and `/sys` contain a wealth of sensitive information, including kernel addresses, hardware configurations, and environment variables of other processes. They also expose writable endpoints that can modify kernel parameters. By default, Landlock **restricts access** to these global endpoints unless explicitly permitted.
    *   *Example:* An attacker exploiting a bug in a server application might try to read `/proc/kallsyms` to bypass **Kernel Address Space Layout Randomization (KASLR)** or read `/proc/self/environ` to steal API keys. If the application's Landlock ruleset does not explicitly grant access to `/proc`, these attempts are immediately blocked.

# 👑 Making Landlock Idiomatic in Nim

Our Nim wrapper balances this low-level control with **high-level safety**. We use type-safe enums like `FsAccess`, `NetAccess`, and `Scope` instead of raw bitmasks. The core of the library is the `restrictTo` procedure, which handles the entire lifecycle while *automatically masking out flags* that the current kernel does not support.

Using Nim's metaprogramming, we can take this a step further. The `toStaticLandlock` macro calculates kernel bitmasks at **compile-time**, replacing runtime loops with literal integers. We also provide a declarative `sandbox:` DSL that transforms a readable block of code into a complex initialization sequence.

Crucially, `restrictTo` (and the `sandbox:` macro) returns a **`Sandboxed` capability object** upon success. This follows the **Witness Pattern**: by requiring this object as an argument in your sensitive procedures, you create a compile-time guarantee that those procedures can *only* be executed after the sandbox has been correctly initialized.

<div style="text-align: center;">
  <img src="/img/real_shield.svg" alt="Shield representing Safety" width="200" />
  <p style="font-size: 0.8em; color: gray;"><em>Image from <a href="https://commons.wikimedia.org/wiki/File:Shield.svg">Wikimedia Commons</a> (Public Domain)</em></p>
</div>

# 💻 Implementation Example

Here is how all these pieces look in a real application. Note how `processInSandbox` requires the `Sandboxed` witness, ensuring it cannot be called accidentally before the restrictions are applied.

```nim
import landlock, os

# This procedure can ONLY be called if the caller provides a 
# 'Sandboxed' witness, proving the process is restricted.
proc processInSandbox(sb: Sandboxed, workDir: string) =
  echo "Working safely in: ", workDir
  writeFile(workDir / "test.txt", "Data secured by Landlock")
  
  # This would fail at runtime due to Landlock:
  # writeFile("/etc/shadow", "evil") 

let myWorkDir = "/tmp/sandbox_data"
if not dirExists(myWorkDir): createDir(myWorkDir)

try:
  # The 'sandbox:' macro returns a Sandboxed witness on success
  let sb = sandbox:
    allow myWorkDir, {ReadFile, WriteFile, MakeReg, ReadDir}
    allowNet 443, {ConnectTcp}
    scope {Signal}
  
  # We pass the witness to our sensitive logic
  processInSandbox(sb, myWorkDir)
  
  echo "Operations completed successfully!"
except LandlockError as e:
  echo "Security initialization failed: ", e.msg
```

# 🏁 Conclusion

Landlock and Nim are a **powerful combination** for building secure systems. By leveraging metaprogramming, we can transform a complex kernel API into a static guarantee enforced by both the compiler and the kernel. It is a pragmatic way to implement the **Principle of Least Privilege** without sacrificing developer productivity.

The complete code for the Nim wrapper and the Proof of Concept is available on GitHub at [https://github.com/ilmanzo/landlock-nim-poc](https://github.com/ilmanzo/landlock-nim-poc).

*Stay secure, stay pragmatic.*