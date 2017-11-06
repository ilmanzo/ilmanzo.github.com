---
layout: post
title: "linux: how to access DHCP options from client"
description: "how to access DHCP options from client"
category: linux
tags: [linux, debian, scripting, sysadmin, dhcp, network]
---
{% include JB/setup %}


As you may know, you can configure any [DHCP](https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol) server to send many options to the
clients; for example to setup dns domains, http proxy (WPAD) and so on.

If you need to access these options from a linux client, you must configure the client to **ASK** the server for the new options, by editing
  `/etc/dhcp/dhclient.conf`, and add an entry like:

{% highlight bash %}
option WPAD code 252 = string;
also request WPAD;
{% endhighlight %}

done that, when you'll ask for a dhcp, the dhclient process will invoke your hook scripts with two
environment variables, `old_WPAD` and `new_WPAD`, with the values before and after the renewal.

so you can put a script in the folder `/etc/dhcp/dhclient-enter-hooks.d` or 
`/etc/dhcp/dhclient-exit-hooks.d` to simply "use" the value, by writing it in
a configuration file or somewhere else. 

{% highlight bash %}
#!/bin/bash
echo "I got a new value of WPAD from DHCP : ${new_WPAD}" > /tmp/wpad.txt
{% endhighlight %}











