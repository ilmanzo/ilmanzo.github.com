---
layout: post
title: "how to see the IP address of a virtual machine before logon"
description: "a small trick to save time when using linux virtual machines"
category: automation
tags: [linux, tips, virtual machine, ip address]
---
{% include JB/setup %}

For testing or development purposes, I do a wide use of small linux virtual machines.

After spawning a new guest (Virtualbox, VMWare or any other), often you want to log on over ssh but you don't yet know its ip address. 
You need to login as 'root' in the console just to issue a quick 'ifconfig', and after writing down the address, you logout and connect with your comfortable terminal.
In order to save some time and keystrokes, I put this in my rc.local of all my guest VMs:

{% highlight bash %}
/sbin/ip addr show|awk '/inet / {print $2}' > /etc/issue
echo >> /etc/issue
{% endhighlight %}

In brief: since the file **/etc/issue** is displayed before login, you get a quick overview of all ipv4 addresses configured. Of course it can be expanded and adapted for your needs.

![a minimalistic screenshot](/img/2014-05-05-Screenshot.png "Screenshot of the new login prompt")




