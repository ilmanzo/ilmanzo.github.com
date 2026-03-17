---
title: "Rootless podman as lab environment"
date: 2026-03-18
tags: ["opensuse", "podman", "containers", "systemd", "linux", "tutorial", salt]
categories: ["linux"]
author: Andrea Manzini
draft: true
---

## intro

Followup from [the previous post](https://ilmanzo.github.io/post/podman_quadlets_tutorial/), today we are going to put our systemd-managed containers to work and use them for some useful tasks.

The idea is to setup an environment to learn how the configuration management [salt](https://saltproject.io/) works, and play/hack around with it, without having to spin up any virtual machine and even needing root or `sudo` rights.

## Setup

I used OpenSUSE Tumbleweed for my experiment, as it lets me test the latest versions of my preferred packages.


```bash
# Install requisites
zypper install podman systemd-container
# This directory will contain our containers (pun intended)
mkdir -p ~/.config/containers/systemd/
```

Now let's prepare our two container quadlets, as we did last time:

```ini
# ~/.config/containers/systemd/salt-master.container
[Unit]
Description=Salt Master Lab

[Container]
Image=registry.opensuse.org/opensuse/leap:15.6
ContainerName=salt-master
HostName=salt-master
Network=saltnet

Volume=%h/salt_lab/srv/salt:/mnt/salt:Z
Volume=%h/salt_lab/srv/pillar:/mnt/pillar:Z
Volume=%h/salt_lab/config/master_custom.conf:/etc/salt/master.d/custom.conf:Z

Exec=bash -c "zypper --non-interactive install salt-master && salt-master -l debug"

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```ini
# ~/.config/containers/systemd/salt-minion.container
[Unit]
Description=Salt Minion Lab
After=salt-master.service

[Container]
Image=registry.opensuse.org/opensuse/leap:15.6
ContainerName=salt-minion
HostName=salt-minion
Network=saltnet

Volume=%h/salt_lab/config/minion.conf:/etc/salt/minion.d/lab_config.conf:Z

Exec=bash -c "zypper --non-interactive install salt-minion && salt-minion -l debug"

[Service]
Restart=always

[Install]
WantedBy=default.target
```

## Why the `:Z` ?

**Rootless Podman** is a security-first tool.

When you mount a volume from your host into a container, Linux security modules (like SELinux) block the container from touching those files by default. The `:Z` flag tells Podman:

"Hey, I'm mounting this folder. Please relabel it so that this specific container (and only this one) has the private permissions to read and write here."

Without `:Z`, your Salt Master sees the folders but gets a **Permission Denied** when it tries to read your `.sls` files, because the host's security layer doesn't recognize the container's "internal" root user as a valid owner.

To make our work persistent, the container will mount some volumes from the host system, so let's give them the directories and the content:

```bash
# Here we will save the server and 'client' configurations
mkdir -p ~/salt_lab/srv/config
# Here we will store our 'infrastructure as code' files
mkdir -p ~/salt_lab/srv/salt 
mkdir -p ~/salt_lab/srv/pillar
```

```yaml
# The Master Config (`~/salt_lab/config/master.conf`)
interface: 0.0.0.0
file_roots:
  base:
    - /mnt/salt
pillar_roots:
  base:
    - /mnt/pillar
```

```yaml
# The Minion Config (`~/salt_lab/config/minion.conf`)
master: salt-master
```

There's another thing new here: the container will need to communicate with each other so we have to create a "network" for them:

```bash
podman network create saltnet
```
In a standard container setup, containers are often isolated or rely on unpredictable IP addresses. By creating the saltnet custom network, we are enabling Service Discovery via Internal DNS. When the Salt Minion tries to connect to the hostname salt-master, it doesn't need to know an IP address; it simply asks the Podman network's built-in DNS resolver. Podman intercepts this request and maps the name `salt-master` to the correct internal container IP (e.g., 10.89.0.2). This creates a stable, "plug-and-play" environment where our infrastructure can find its "brain" (the Master) automatically, even if the containers are restarted or assigned new IPs behind the scenes.

Without a custom network, Podman defaults to a basic bridge that does not provide name resolution. By using `saltnet`, we move away from hardcoding fragile IP addresses and toward a declarative infrastructure where services find each other by identity.

Now you can finally start the container/services:

```bash
systemctl --user start salt-master salt-minion
```
(on the first time it may take a bit to download the images and install the salt packages)

## The SaltStack Glossary

For a beginner, Salt can sound like a kitchen inventory. Here is the breakdown:

| **Term**         | **Definition**                                                                                           | **Analogous To...** |
| ---------------- | -------------------------------------------------------------------------------------------------------- | ------------------- |
| **Master**       | The central server that stores configurations and issues commands.                                       | The Conductor       |
| **Minion**       | The agent running on the target server that executes the Master's orders.                                | The Musicians       |
| **State (.sls)** | A YAML file describing the **desired end-state** of a system (e.g., "This package _must_ be installed"). | The Sheet Music     |
| **Pillar**       | Secure, private data (like passwords) defined on the Master and sent only to specific Minions.           | The Secret Stash    |
| **Grains**       | Static "facts" about a Minion (OS version, CPU, RAM) that it reports to the Master.                      | The ID Card         |
| **JID**          | Job ID. Every command sent by the Master gets a unique timestamped ID.                                   | The Receipt         |


## Communication check

```bash
# podman exec -it salt-minion ping -c3 salt-master 

PING salt-master.dns.podman (10.89.0.6) 56(84) bytes of data. 64 bytes from salt-master (10.89.0.6): icmp_seq=1 ttl=64 time=0.014 ms 64 bytes from salt-master (10.89.0.6): icmp_seq=2 ttl=64 time=0.037 ms 64 bytes from salt-master (10.89.0.6): icmp_seq=3 ttl=64 time=0.034 ms
```

login to the master and check pending keys:

```bash
$ podman exec -it salt-master bash

salt-master:/ # salt-key -L
Accepted Keys:
Denied Keys:
Unaccepted Keys:
salt-minion           <--- 
Rejected Keys:
```

we need to accept the key!

```bash
salt-master:/ # salt-key -a salt-minion -y 
The following keys are going to be accepted:
Unaccepted Keys:
salt-minion
Key for minion salt-minion accepted.

```

now let's ensure that the master can control the minion:

```bash
salt-master:/ # salt 'salt-minion' test.ping
salt-minion:
  True
```

## The "Key Exchange"

When you start a fresh Minion, it doesn't just trust the Master, and the Master definitely doesn't trust the Minion. Here is the play-by-play:

- As soon as the `salt-minion` service starts for the first time, it generates its own **RSA Key Pair** (a public key and a private key) locally in `/etc/salt/pki/minion/`.

- The Minion sends its **Public Key** over the network to the Master. It essentially says: _"Hi, I'm salt-minion. Here is my public key. I'd like to join your infrastructure."_

- The Master receives the key and places it in a "waiting room" (the `/etc/salt/pki/master/minions_pre/` directory).

- At this stage, if you run `salt-key -L`, you see the minion in **Red (Unaccepted)**.
    
- The Master will **not** send any commands to this minion yet.
    
- When you run `salt-key -a salt-minion`, the Master moves that public key into the "Accepted" folder (`/etc/salt/pki/master/minions/`).

- The Master then sends **its own Public Key** back to the Minion.
    
- **Now they both have each other's public keys.** They can now use these to negotiate a temporary **AES session key** for super-fast, encrypted communication.
    
If a hacker tried to spoof your `salt-minion` by naming their laptop the same thing and joining your network:

1. The Master would see a **new public key** for an existing name.
    
2. Salt would throw a massive warning: **"Wait! The key for salt-minion has changed! This might be a Man-in-the-Middle attack!"**
    
3. The Master will refuse to talk to the "new" minion until you manually clear the old key and accept the new one.

### Pro-Tips !

In a **Rootless Podman** setup, these keys live inside the container's virtual filesystem. If you delete the container without a persistent volume for `/etc/salt/pki`, you will have to re-accept the keys every time you restart the lab!

To avoid this, we'd need to mount yet another volume from the host filesystem, where the server can persist the keys.

A Cheat Sheet for key management:

| **Command**          | **Action**                                          |
| -------------------- | --------------------------------------------------- |
| `salt-key -L`        | **List** all keys (Accepted, Unaccepted, Rejected). |
| `salt-key -a <name>` | **Accept** a specific minion key.                   |
| `salt-key -A`        | **Accept all** pending keys (use with caution!).    |
| `salt-key -d <name>` | **Delete** a key (effectively "firing" the minion). |
| `salt-key -f <name>` | **Fingerprint** - Show the "ID card" of a key.      |


- **Fingerprint:** A short string of letters and numbers that represents the key. In a high-security environment, you should compare the fingerprint on the Minion (`salt-call key.finger`) with the one on the Master (`salt-key -F`) before accepting.
    
- **PKI (Public Key Infrastructure):** The system Salt uses to manage these keys.
    
- **Encryption:** Salt uses **AES-256** for the actual data transfer, which is the industry standard for secure government and banking data.


## let the beat control your body

Instead of running manual commands, `Salt` is designed to use **State Files (SLS)**. These describe how the system _should_ look.

On your **host machine** (outside the container), go to your `~/salt_lab/srv/salt` folder and create a file named `common_tools.sls`:


```yaml
install_useful_packages:
  pkg.installed:
    - pkgs:
      - htop
      - ripgrep
      - fzf

create_test_file:
  file.managed:
    - name: /etc/salt_was_here.txt
    - contents: |
        This minion is managed by SaltStack.
        Last updated: {{ salt['system.get_system_date_time']() }}
    - user: root
    - group: root
    - mode: '0644'
```

Now, tell the Master to apply that configuration to the Minion. 

```bash
podman exec -it salt-master salt 'salt-minion' state.apply common_tools
```
(takes some time)

Once it says **Succeeded: 2**, you can check the file inside the Minion to see your handiwork:

```bash
podman exec -it salt-minion cat /etc/salt_was_here.txt 

This minion is managed by SaltStack. Last updated: 2026-03-17 14:11:28
```



## Automating the Reconciliation Loop

To make the Minion stay in sync with the Master's files automatically, we use a **Highstate** schedule. Instead of you typing `state.apply`, the Minion will "check in" every X minutes to see if its reality matches the Master's instructions.

Create a new file on your host: `~/salt_lab/srv/salt/schedule.sls`

```yaml
# Ensure the minion checks in every 5 minutes
sync_with_master_periodically:
  schedule.present:
    - function: state.highstate
    - minutes: 5
```

Salt needs a `top.sls` to know that every Minion should always have its states applied. Create `~/salt_lab/srv/salt/top.sls`:


```yaml
base:
  '*':
    - common_tools
    - schedule
```

Run this once to tell the Minion to start its own internal timer:

```bash
podman exec -it salt-master salt '*' state.apply
```

Now, if you add a new package to `common_tools.sls` on your host, you don't have to do anything. Within 5 minutes, the Minion will notice the difference and install the package automatically.

In a proper **gitops** context, the state files will be versioned in a repository, where the master can pull them and apply to the minions.

## some useful aliases

```bash
alias salt="podman exec -it salt-master salt" 
alias salt-key="podman exec -it salt-master salt-key" 
alias salt-run="podman exec -it salt-master salt-run"
alias salt-logs="podman logs -f salt-master" 
alias minion-logs="podman logs -f salt-minion"
```

## wrapping up

Building a SaltStack lab doesn't have to mean compromising your host system's security or wrestling with complex virtual machine networking. By leveraging openSUSE Tumbleweed, Rootless Podman, and Quadlets, we’ve created an environment that is secure, declarative, automated.

Whether you are a developer looking to test configuration changes locally or a SysAdmin practicing for the SaltStack Certified Engineer exam, this containerized approach provides a fast, disposable, and professional-grade playground.

The "plumbing" is now out of the way. Your network is live, your keys are accepted, and your minions are ready. The only question left is: What will you automate next?

Bonus Challenge: Try adding a second minion container to your saltnet. Can you use [Grains](https://docs.saltproject.io/salt/user-guide/en/latest/topics/grains.html) to ensure apache only installs on the first minion and nginx only on the second?



