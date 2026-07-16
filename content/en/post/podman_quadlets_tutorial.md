---
title: "A Friendly Guide to Podman Quadlets"
date: 2026-02-03
tags: ["opensuse", "podman", "containers", "systemd", "linux", "tutorial"]
categories: ["linux"]
author: Andrea Manzini
---

## 🦎 Hi geekos!

If you’ve been running containers on your [Leap](https://get.opensuse.org/leap) or [Tumbleweed](https://get.opensuse.org/tumbleweed/) machine, you probably started with `podman run` commands. Maybe you moved to `Docker Compose` files to manage stacks. Those are great tools, but they have a limitation, as they don't integrate natively with `systemd`, your operating system's init system.

When your server reboots, do your containers start back up automatically? If a container crashes, does it restart? How do you view its logs alongside your system journal?

Today we'll explore **Podman Quadlets**.

![podman_logo](/img/podman-logo.png)


Quadlets are the modern, "native" way to run Podman containers as fully-fledged systemd services. If you love [OpenSUSE](https://www.opensuse.org/) because of its stability and robust engineering, you'll love Quadlets. They turn container definitions into rock-solid system services without requiring you to write complex systemd unit files from scratch.

Let’s get your openSUSE machine set up with Quadlets!

## 👤 By Root or By User?

In the openSUSE world, we value security. Podman shines because it allows "rootless" containers—running containers as your regular user without needing `sudo`.

While you *can* run Quadlets as root (system-wide), today we are going to focus on **Rootless (User) Quadlets**. It’s safer, easier to manage, and doesn't require elevated privileges.

## 🛠️ The Prerequisites on openSUSE

First, ensure your system is up to date and you have Podman installed.

Open your terminal and run:

```bash
# For Leap or Tumbleweed
sudo zypper refresh
sudo zypper update
sudo zypper install podman
```

## 🎬 Setting the Stage
Systemd needs to know where to look for these Quadlet files. For a rootless user, there is a specific directory located in your home folder. It usually doesn't exist by default, so let's create it.
This is where all the magic will happen today.

```Bash
MYDIR=~/.config/containers/systemd/
mkdir -p $MYDIR && cd $MYDIR
```

### What is a Quadlet exactly?
A *Quadlet* is just a text file similar to an INI file. You describe what you want (container image, ports, volumes), and systemd uses a generator to convert that file into a real service unit behind the scenes.

The most common type of Quadlet file ends in `.container`.

## 👋 Example 1: The "Hello World" Web Server (Caddy)
Let's start simple. We want to run the [Caddy web server](https://caddyserver.com/). We want it to start automatically on boot, restart if it crashes, and listen on port 8080.

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

[Service]
# If it crashes, restart it
Restart=always
# Give it time to pull heavy images on slower connections
TimeoutStartSec=600

[Install]
# This makes sure it starts when your user session starts (or boot via linger)
WantedBy=default.target
```

Look at how readable that is! It’s much cleaner than a giant `podman run` command kept together with backslashes.

## ✨ The "Magic" Activation Step
If you run `podman ps` right now, nothing is running. You've created the definitions, but systemd doesn't know they exist yet.

We need to tell systemd to scan our configuration directory and generate the actual service units. Because we are running in rootless mode, we use the --user flag.

Run this command in your terminal:

```Bash
systemctl --user daemon-reload
```

Check the journal logs; if you didn't get any error messages in, it worked:

Systemd took your `myserver.container` and silently generated a `myserver.service`.

Start the web server:

```Bash
systemctl --user start myserver.service
```

(this will take a bit of time on the first run, because `podman` needs to pull the container image)

Check its status:

```Bash
systemctl --user status myserver.service
```

You should see enthusiastic green text saying "active (running)".

Test it! Open Firefox and visit http://localhost:8080. You should see the default Caddy Home Page.

```
$ curl -I http://localhost:8080
HTTP/1.1 200 OK
Accept-Ranges: bytes
Content-Length: 18753
Content-Type: text/html; charset=utf-8
Etag: "dfzwznr2vfggegx"
Last-Modified: Wed, 28 Jan 2026 03:49:55 GMT
Server: Caddy
Vary: Accept-Encoding
Date: Tue, 03 Feb 2026 10:00:49 GMT
```


## 🗄️ Example 2: The Database (MariaDB with Secrets)
Real-world applications usually need a database, and you should never put passwords directly into the main config file.

Let's set up *MariaDB*, a favorite in the openSUSE ecosystem, and pass the credentials securely using a separate environment file.

### 1. Create the secret file
Create a file named `mariadb.env` in the same directory.

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
Image=docker.io/library/mariadb:11.8
ContainerName=production-db

# Tell Podman where to find the environment variables
EnvironmentFile=%h/.config/containers/systemd/mariadb.env

# Persistent storage for the database files
Volume=mysql-data:/var/lib/mysql:Z

# We usually don't publish DB ports to the outside world, 
# but this is just a test example. DO NOT DO THIS IN PRODUCTION!
PublishPort=127.0.0.1:3306:3306

[Service]
Restart=on-failure
TimeoutStartSec=600

[Install]
WantedBy=default.target
```

Note: Did you see %h in the file path? That’s a systemd specifier that automatically fills in your home directory path (e.g., /home/geeko).


## 🤹 Managing Your New Services
Now you manage these containers exactly like you manage all other system services: Apache, SSH, or firewalld on openSUSE, using `systemctl`.


Start the database:

```Bash
systemctl --user daemon-reload && systemctl --user start mydb.service
```

View logs (the systemd way):

```Bash
journalctl --user -u mydb.service
```

No more podman logs. Use the powerful journal!
To follow the logs in real-time:

```Bash
journalctl --user -f -u mydb.service
```

Let's test if it works:

```
$ zypper in mariadb-client
$ mariadb -h localhost -u appuser --protocol=TCP --skip-ssl -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 6
Server version: 10.11.15-MariaDB-ubu2204 mariadb.org binary distribution

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> use myappdb ; show tables;
Database changed
Empty set (0.000 sec)
```

For a proper Production-ready database you'd need of course some extra tuning: define proper data volume permissions, enable ssl, configure replication/backups, and so on; but you get the point :smile:


## 🥾 The Final Touch - Start on Boot
Right now, if you reboot your openSUSE machine, these containers won't start until you actually log in via GUI or SSH.

To make rootless containers start instantly when the server boots up (even before you log in), you need to enable "lingering" for your user account.

By default, systemd user instances are started when you log in and stopped when you log out. Enabling lingering tells systemd to start your user manager at boot and keep it running even when you are not logged in. This is essential for servers, as it ensures your containers launch immediately when the machine powers on, without waiting for a user session.


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

Tip: for debug purposes, you can always inspect and read the *generated* systemd unit files by looking in `/var/run/user/$UID/systemd/generator` :

```
$ ls -l /var/run/user/1000/systemd/generator

drwxr-xr-x. 2 andrea andrea   80 Feb  3 11:50 default.target.wants
-rw-r--r--. 1 andrea andrea 1335 Feb  3 11:50 mydb.service
-rw-r--r--. 1 andrea andrea 1320 Feb  3 11:50 myserver.service
```

That's all for now! You have handy container worload, integrated deeply with your openSUSE system. 
On a future post, we will explore more advanced features, such as *internal networking* (container-to-container communication), *Resource Limits*, *Health Checks*, *Secrets Management* and so on.
Happy podman-ing!


