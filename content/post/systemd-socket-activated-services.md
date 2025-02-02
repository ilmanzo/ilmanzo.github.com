---
layout: post
title: "Systemd Socket Activation Explained"
description: "Stop Wasting Resources: how to start your services on demand"
categories: [linux, automation, sysadmin]
tags: [systemd, sysadmin, command line, linux, services, server, socket, learning, tutorial]
author: Andrea Manzini
date: 2025-02-03
---

## 💭 What ? 

Imagine a web server that only starts when someone actually tries to access it. Or a database that spins up only when a query comes in: this is the *magic* of socket activation. The concept is not new, as old-school sysadmins may are used to see something like [inetd](https://en.wikipedia.org/wiki/Inetd) or [xinetd](https://en.wikipedia.org/wiki/Xinetd) for on-demand service activation in the past.

As some cool projects like [cockpit](https://cockpit-project.org/) have already started using this little-known feature, in this blog post we'll see the basics and try to get familiarity with the tooling.

## 🔑 Under the hood

the key components are:
- a `.socket` unit file: it defines the socket (port, protocol) to listen on.
- a `.service` unit file: it defines the service to be started upon connection.

systemd associates the `.socket` with the `.service`:

1. systemd listens on the socket
2. A client connects to the socket
3. systemd detects the connection
4. systemd starts the associated service
5. systemd hands off the socket to the service
6. The service now handles the connection directly

## 🔨 Let's try out

Let's start with a blank slate: [OpenSUSE Leap 16.0](https://get.opensuse.org/leap/16.0/) is in α-testing phase so we can use it as a playfield :smile: but at the end you can use the distro you prefer, provided it comes with the [systemd](https://systemd.io/) service manager.

As a demo scenario, suppose you have built an awesome `dice-as-a-service`™ that returns you a random number each time it gets invoked. Of course it's RESTful and JSON based! 

{{< highlight python >}}
from flask import Flask, jsonify
import random

app = Flask(__name__)

@app.route('/roll')
def roll_dice():
    return jsonify({"result": random.randint(1, 6)})
{{</ highlight >}}

(note: this is only an example, a proper production app should check inputs, handle errors, log in a proper way, and so on)

{{< highlight bash  >}}
$ sudo zypper in python3-Flask
$ flask --app dice.py run &
[1] 10100
andrea@toolbox-andrea-user:/tmp>  * Serving Flask app 'dice.py'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on http://127.0.0.1:5000
Press CTRL+C to quit
{{</ highlight >}}

Let's test it: 
{{< highlight bash  >}}
$ curl http://127.0.0.1:5000/roll 
127.0.0.1 - - [01/Feb/2025 10:30:46] "GET /roll HTTP/1.1" 200 -
{"result":2}
$ curl http://127.0.0.1:5000/roll 
127.0.0.1 - - [01/Feb/2025 10:30:49] "GET /roll HTTP/1.1" 200 -
{"result":1}
$ curl http://127.0.0.1:5000/roll 
127.0.0.1 - - [01/Feb/2025 10:30:59] "GET /roll HTTP/1.1" 200 -
{"result":6}
$ kill %1
[1]+  Terminated              flask --app dice.py run
{{</ highlight >}}

Seems working! 

## 🌿 Don't waste resources

After some frantic weeks, you discover that your service is actually used, but not as much you expected. Only some people call it during to get random numbers, and only a few times per day; so it seems a bit of wasteful to have a Python interpreter always running and taking some megabytes of memory for a such small purpose. So, let's prepare a `socket` unit file: 

```ini
# /etc/systemd/system/diceroll.socket 
[Unit]
Description=Socket for diceroll service activation
PartOf=diceroll.service

[Socket]
ListenStream=5000
NoDelay=true
Backlog=128

[Install]
WantedBy=sockets.target
```

and the corresponding `service` file:

```ini
# /etc/systemd/system/diceroll.service 
[Unit]
Description=Socket-activated dice rolling service
Requires=diceroll.socket
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/dice_ng.py
Type=simple
```

Let's try it; one important note: only the `.socket` unit should be started and enabled at startup; the correspondind `.service` file will be automatically started on demand. 

```bash
$ systemctl daemon-reload
$ systemctl enable --now diceroll.socket
$ curl http://127.0.0.1:5000/roll
curl: (56) Recv failure: Connection reset by peer
```

Whoa, something has gone wrong :thinking:

## 🩹 Fixing the issue

There's an issue in our solution: when the server spawns up, it tries to listen on the connection it finds the socket already in use by systemd. We need to change our application to handle the socket opened and passed by systemd:

{{< highlight python >}}
import socket
import os, sys
import flask, random
from werkzeug.serving import make_server

app = flask.Flask(__name__)

@app.route('/roll')
def roll_dice():
    return {'result': random.randint(1, 6)}

def get_systemd_socket():
    """Retrieve the socket passed by systemd"""
    listen_fds = int(os.environ.get('LISTEN_FDS', 0))
    if listen_fds != 1:
        sys.stderr.write("Error: systemd did not provide exactly one socket.\n")
        sys.exit(1)
    sock = socket.fromfd(3, socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    return sock

if __name__ == '__main__':
    sock = get_systemd_socket()
    server = make_server('localhost', 5000, app, fd=sock.fileno())
    server.serve_forever()
{{</ highlight >}}


```bash
$ curl http://127.0.0.1:5000/roll
{"result":1}
```

Now it works and the server starts on demand. Someone could notice that it runs forever and never stops, so after the first startup, it stays up and consuming some resources, even when idle! 
On the other hand, we cannot simply have a service that serves one connection and then immediately quit, because handling lots of connections would be less efficient and quite similar to a inetd/CGI server. 

## 🖐️ Please stop ?

To solve this inconvenience, we could add some checks and logic in our application in order to quit when has been idle for too long. A similar effect can be obtained by using the  `--exit-idle-time` option of the [`systemd-socket-proxyd` utility](https://www.freedesktop.org/software/systemd/man/latest/systemd-socket-proxyd.html), we can even use a [systemd timer](https://documentation.suse.com/smart/systems-management/html/systemd-working-with-timers/index.html) to gracefully kill our application after some pre-defined time. The first solution is more robust and cleaner but it's out of scope of this tutorial, maybe we will get deeper in a future article; as we want to play with `systemd` features for now:

```ini
# /etc/systemd/system/diceroll.service
[Unit]
Description=Socket-activated dice rolling service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/dice_ng.py
Type=simple
TimeoutStartSec=1min  # Timeout after 1 minute of inactivity (no new connections)
# ExecStop will be executed when the TimeoutStartSec is reached.
ExecStop=/bin/systemctl stop your-app.service

[Install]
WantedBy=multi-user.target
```

## ⌛ How it works:
1. The `.socket` file listens for connections.
2. When a connection arrives, it activates the application service (`diceroll.service`).
3. Systemd starts the application service.  The `TimeoutStartSec` timer starts counting.
4. If no new connections arrive within the `TimeoutStartSec` period, `systemd` considers the service start-up as failed and executes the `ExecStop` command, which stops the application.

## :wave: Bye

While we've explored several methods for managing timeouts and service lifecycles with systemd, it's clear that the system is a powerful and complex beast.  Many aspects of systemd remain less widely known, and new features and capabilities are continually being added with each new version.  This exploration highlights just a fraction of its potential, and further investigation into its more advanced functionalities can often unlock even more elegant and efficient solutions for service management and automation.  Whether it's leveraging timers, socket activation, or exploring the intricacies of dependencies and targets, systemd offers a deep toolbox for administrators and developers alike.
