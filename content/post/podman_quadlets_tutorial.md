---
title: "Level Up Your Container Game: A Friendly Guide to Podman Quadlets"
date: 2026-02-01
draft: true
tags: ["opensuse", "podman", "containers", "systemd", "linux", "tutorial"]
categories: ["linux"]
author: Andrea Manzini
---

Hi geekos!

If you’ve been running containers on your Leap or Tumbleweed machine, you probably started with `podman run` commands. Maybe you graduated to Docker Compose files to manage stacks. Those are great tools, but they have a limitation: they don't integrate natively with your operating system's init system.

When your server reboots, do your containers start back up automatically? If a container crashes, does it restart? How do you view its logs alongside your system journal?

Enter **Podman Quadlets**.

Quadlets are the modern, "native" way to run Podman containers as fully-fledged systemd services. If you love openSUSE because of its stability and robust engineering, you'll love Quadlets. They turn container definitions into rock-solid system services without requiring you to write complex systemd unit files from scratch.

Let’s get your openSUSE machine set up with Quadlets!

## By Root or By User?

In the openSUSE world, we value security. Podman shines because it allows "rootless" containers—running containers as your regular user without needing `sudo`.

While you *can* run Quadlets as root (system-wide), today we are going to focus on **Rootless (User) Quadlets**. It’s safer, easier to manage, and doesn't require elevated privileges.

## Step 0: The Prerequisites on openSUSE

First, ensure your system is up to date and you have Podman installed.

Open your terminal and run:

```bash
# For Leap or Tumbleweed
sudo zypper refresh
sudo zypper update
sudo zypper install podman
```

## Step 1 : Setting the Stage
Systemd needs to know where to look for these Quadlet files. For a rootless user, there is a specific directory located in your home folder. It usually doesn't exist by default, so let's create it.
This is where all the magic will happen today.

```Bash
mkdir -p ~/.config/containers/systemd/
cd ~/.config/containers/systemd/
```

### What is a Quadlet exactly?
A *Quadlet* is just a text file similar to an INI file. You describe what you want (container image, ports, volumes), and systemd uses a generator to convert that file into a real service unit behind the scenes.

The most common type of Quadlet file ends in `.container`.

### Example 1: The "Hello World" Web Server (Caddy)
Let's start simple. We want to run the Caddy web server. We want it to start automatically on boot, restart if it crashes, and listen on port 8080.

Create a new file inside `~/.config/containers/systemd/` named `myserver.container`.

You can use nano, [neo]vim, micro or your favorite GUI text editor.


File: `~/.config/containers/systemd/myserver.container`

```ini
[Unit]
Description=My Caddy Web Server
# Wait until networking is up before starting
After=network-online.target

[Container]
# The image to use (always good practice to specify the registry)
Image=docker.io/library/caddy:latest

# Map host port 8080 to container port 80
PublishPort=8080:80

# Mount a volume for persistent data. 
# The ':Z' is important for SELinux on openSUSE!
Volume=caddy-data:/data:Z

# Create a handy index.html just for testing
ExecStartPre=/usr/bin/sh -c "echo 'Hello from openSUSE Quadlets!' > /data/index.html"

[Service]
# If it crashes, restart it
Restart=always
# Give it time to pull heavy images on slower connections
TimeoutStartSec=900

[Install]
# This makes sure it starts when your user session starts (or boot via linger)
WantedBy=default.target
```

Look at how readable that is! It’s much cleaner than a giant podman run command strung together with backslashes.

### Example 2: The Advanced Database (MariaDB with Secrets)
Real-world applications usually need a database, and you should never put passwords directly into the main config file.

Let's set up MariaDB, a favorite in the openSUSE ecosystem, and pass the credentials securely using a separate environment file.

### 1. Create the secret file
Create a file named mariadb.env in the same directory.

File: `~/.config/containers/systemd/mariadb.env`

```Bash
MYSQL_ROOT_PASSWORD=SuperSecretOpenSUSEPassword!
MYSQL_DATABASE=myappdb
MYSQL_USER=appuser
MYSQL_PASSWORD=apppassword
```

Security Tip: On a real system, run `chmod 600` mariadb.env so only your user can read this file!

### 2. Create the Container file
Now create the Quadlet file that references those secrets.

File: `~/.config/containers/systemd/mydb.container`

```ini
[Unit]
Description=MariaDB Database Service
After=network-online.target

[Container]
Image=docker.io/library/mariadb:10.11
ContainerName=production-db

# Tell Podman where to find the environment variables
EnvironmentFile=%h/.config/containers/systemd/mariadb.env

# Persistent storage for the database files
Volume=mysql-data:/var/lib/mysql:Z

# We usually don't publish DB ports to the outside world, 
# but if you needed to, you'd uncomment the next line:
# PublishPort=3306:3306

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
```

Note: Did you see %h in the file path? That’s a systemd specifier that automatically fills in your home directory path (e.g., /home/geeko).

## Step 3: The "Magic" Activation Step
If you run `podman ps` right now, nothing is running. You've created the definitions, but systemd doesn't know they exist yet.

We need to tell systemd to scan our configuration directory and generate the actual service units. Because we are running in rootless mode, we use the --user flag.

Run this command in your terminal:

```Bash
systemctl --user daemon-reload
```

If you didn't get any error messages, it worked!

Systemd took your `myserver.container` and silently generated a `myserver.service`.

## Step 4: Managing Your New Services
Now you manage these containers exactly like you manage Apache, SSH, or firewalld on openSUSE, using `systemctl`.

Start the web server:

```Bash
systemctl --user start myserver.service
```

Check its status:

```Bash
systemctl --user status myserver.service
```

You should see enthusiastic green text saying "active (running)".

Test it! Open Firefox and visit http://localhost:8080. You should see "Hello from openSUSE Quadlets!".

Start the database:

```Bash
systemctl --user start mydb.service
```

View logs (the systemd way):

No more podman logs. Use the powerful journal!

```Bash
# Follow the logs in real-time
journalctl --user -f -u mydb.service
```

## Step 5: The Final Touch - Start on Boot
Right now, if you reboot your openSUSE machine, these containers won't start until you actually log in via GUI or SSH.

To make rootless containers start instantly when the server boots up (even before you log in), you need to enable "lingering" for your user account.

Run this once:

```Bash
# Replace 'geeko' with your actual username
sudo loginctl enable-linger geeko
```

Now, enable your services so they start automatically:

```Bash
systemctl --user enable myserver.service
systemctl --user enable mydb.service
```

That's it. You now have production-ready containers integrated deeply with your openSUSE system. 
On a next post, we will explore more advanced features, such as internal networking, Resource Limits, Health Checks, Secrets Management and so on.
Happy podman-ing!


