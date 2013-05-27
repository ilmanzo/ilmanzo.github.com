---
layout: post
title: "Automate Cisco ssh connections with plink in Windows"
description: ""
category:
tags: [cisco ssh automation putty]
---
{% include JB/setup %}

A simple way to send a bunch of commands to any ssh device (in my case, Cisco appliances)...

* create a batch file with commands echoed inside:

<pre>
    @echo off
    echo ter len 0
    echo show ver
    echo show clock
    echo exit
</pre>

* execute the batch, piping its output to [plink.exe](http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html)
(putty command link ssh client):

 ```
     c:\> commands.bat | plink -ssh -l username -pw password  11.22.33.44
 ```
