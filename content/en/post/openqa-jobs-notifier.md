---
layout: post
title: "get notifications about openQA job status"
description: "how to receive notification about your openQA job status update"
categories: automation
tags: [linux, bash, programming, testing, automation]
author: Andrea Manzini
date: 2022-10-05
---

I got bored of *'waiting'* for an [OpenQA](http://open.qa/) [openSUSE](https://openqa.opensuse.org/) job to complete, so I wrote this quick and dirty script...

For the same purpose there's also the excellent and full-fledged [openqa-mon](https://openqa-bites.github.io/posts/2021-02-25-openqa-mon/), but I took the chance to learn something by implementing a simpler version myself.

<!--more-->

{{< highlight bash >}}
#!/bin/sh
JOB=$1
if [ -z "$JOB" ]; then
  echo "please provide job number as parameter"
  exit 
fi

MESSAGE='Your job is ready!'
JOBURL=https://openqa.opensuse.org/tests/$JOB

while :
do
  STATE=$(openqa-cli api -o3 jobs/$JOB | jq .job.state)
  if [ $STATE != \"scheduled\" ]; then
    notify-send $MESSAGE $JOBURL
    echo $MESSAGE $JOBURL
    exit
  fi
  sleep 5
done
{{</ highlight >}}

To use it, simply run the script with the job number as first and only parameter, and you'll get both a console and desktop notification when the status changes, so you can easily start to follow it with the browser, debug, download assets and so on.

As requirement, you'll need to have some packages installed:
- `openqa-cli` installed and configured (package: `openQA-client` in openSUSE)
- packages: `jq`, `notify-send` (packages: `jq` and `libnotify-tools` in openSUSE)

Have fun!

