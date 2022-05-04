---
layout: post
title: "Linux: get simple I/O statistics per process"
description: ""
categories: sysadmin
tags: [linux, python, sysadmin, monitoring]
author: Andrea Manzini
date: 2014-08-22
---

I had a trouble with a long process running and wish to know how much I/O
this process is doing, so I wrote this quick and dirty python 2.x script:

{{< highlight python >}}
import time,sys,datetime

def read_stat(pid):
  f=open("/proc/%s/io" % pid ,"r")
  for line in f:
    if line.startswith('rchar'):
      rchar=line.split(':')[1]
      continue
    if line.startswith('wchar'):
      wchar=line.split(':')[1]
      continue
  f.close()
  return int(rchar),int(wchar)

pid=sys.argv[1]
r0,w0 = read_stat(pid)

while 1:
  time.sleep(1)
  r1,w1 = read_stat(pid)
  print "%s\t\tr=%s\t\tw=%s" % (datetime.datetime.now().time(),r1-r0,w1-w0)
  r0,w0=r1,w1
{{</ highlight >}}

You must give the process PID number as input to the script. In the output you
get the read/write throughput of the process in bytes per second, for instance:

{{< highlight bash >}}
# python /root/iostat.py 26148
15:59:57.272866         r=208           w=850
15:59:58.269857         r=0             w=871
15:59:59.269906         r=0             w=4194246
16:00:00.270497         r=165569        w=4194171
16:00:01.290003         r=48            w=30095
16:00:02.290123         r=165584        w=4197511
16:00:03.290320         r=0             w=7100
16:00:04.290075         r=0             w=4200859
16:00:05.291754         r=29264618      w=29270412
16:00:06.290484         r=32            w=4195722
16:00:07.360245         r=29264635      w=33459616
16:00:08.360573         r=8             w=0
16:00:09.360337         r=16            w=4101346
16:00:10.360292         r=0             w=4037
16:00:11.372133         r=16            w=0
16:00:12.370385         r=48            w=456
16:00:13.370890         r=0             w=0
16:00:14.370800         r=270           w=450
16:00:15.410800         r=908           w=540
16:00:16.410604         r=24            w=0
{{</ highlight >}}



