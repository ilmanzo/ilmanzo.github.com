---
layout: post
description: "An utility to simplify monitoring openqa job clones"
title: "Stop Wasting Resources: Systemd Socket Activation Explained"
categories: [linux, automation, sysadmin]
tags: [systemd, sysadmin, command line, linux, services, server, socket, learning, tutorial]
author: Andrea Manzini
date: 2025-02-03
draft: true
---

## What ? 

Imagine a web server that only starts when someone actually tries to access it. Or a database that spins up only when a query comes in. This is the magic of socket activation. The on-demand-startup concept is not new, as old sysadmins may have used something like [Tcp Wrappers](https://en.wikipedia.org/wiki/TCP_Wrappers).

As some projects like [cockpit](https://cockpit-project.org/) have already started using this little-known feature, in this blog post we'll see the basics and try to get familiarity.

## How ?

Let's start with a blank slate: [OpenSUSE Leap 16.0](https://get.opensuse.org/leap/16.0/) is in testing phase so we can use it as a playfield :smile: but you can use the distro you prefer, provided it comes with the [systemd](https://systemd.io/) service manager.

As a demo scenario, suppose you have built an awesome `dice-as-a-service` :tm: that returns you a random number each time it gets invoked. Of course it's RESTful and json based! 

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
$ flask  --app dice.py  run &
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

## Don't waste resources

After some frantic weeks, you discover that your service is actually used, but not as much you expected. Only some people call it during to get random numbers, and only a few times per day; so it seems a bit of wasteful to have a Python interpreter always running and taking some megabytes of memory just for it.




## Bye

