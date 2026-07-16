---
layout: post
title: "simple and easy linux job queue"
description: "exploiting linux printing queue facility to manage heterogeneous jobs"
categories: linux
tags: [linux, script, job, queue, batch]
author: Andrea Manzini
date: 2015-12-21
---

Recently I have been in a situation where I needed a simple 'batch' job scheduler, where I could submit some long-running tasks to a server and have a 'system' that serialize access the execution with some basic job control facilities (remove a job from the queue, stop the processing, and so on).

Linux printing subsystem is already designed to do this, and we can exploit the CUPS printing subsystem to run our "batch" jobs.

In practice we need to create a "fake" printer who outputs to /dev/null, but when invoked its real job is executed in an "interface script" that is the real data manager. An example could be a script like this:

{{< highlight bash >}}
  #!/bin/sh
  # save this as file script.txt
  # this script replaces every occurrence of "apple" with "banana" inside a text file
  job="$1"
  user="$2"
  title="$3"
  numcopies="$4"
  options="$5"
  filename="$6"
  /usr/bin/logger "starting script, got parameters: $1^$2^$3^$4^$5^$6"
  /bin/sed s/apple/banana/g $filename > /var/spool/lpd/fixed_$title
  /usr/bin/logger "ending script"
{{</ highlight >}}

to install this , we need to feed it to a new dummy definition:

{{< highlight bash >}}
  lpadmin -p converter -E -iscript.txt -vfile:/dev/null
{{</ highlight >}}

if we make some mistakes in the script, don't forget to remove the printer before redefining it:

{{< highlight bash >}}
  lpadmin -x converter
{{</ highlight >}}

to test it, we prepare a simple text file:

{{< highlight bash >}}
  $ cat minion.txt
  I like apples
  I like apples very much
  More apples!!
{{</ highlight >}}

then we can "print" it with our new printer, making the script run doing it business...

{{< highlight bash >}}
  $ lp -d converter minion.txt
  request id is converter-28 (1 file(s))
{{</ highlight >}}

...and inspect the output:

{{< highlight bash >}}
  $ cat /var/spool/lpd/fixed_minion.txt
  I like bananas
  I like bananas very much
  More bananas!!
{{</ highlight >}}

to inspect the queue, we can use the standard commands:

{{< highlight bash >}}
lpstat -o  # to check current running jobs
lpstat -W completed # to check past jobs already finished
{{</ highlight >}}

to remove a job from the queue,

{{< highlight bash >}}
cancel [id] converter
cancel -a converter
{{</ highlight >}}

with this technique, you can easily prepare fake printers that manages AVI conversion, mp3 playing, ftp file upload... And any kind of long running task you can think about...

Enjoy!



