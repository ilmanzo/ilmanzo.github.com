---
layout: post
title: "redirect output of an already running process"
description: "how to store standard output/error of a process after the execution"
category: linux
tags: [linux sysadmin gdb scripting]
---
{% include JB/setup %}

Long story short: you have launched your script/program but forgot to redirect the output to a file for later inspection.

{% highlight python %}
#!/usr/bin/python3
#sample endless running program that prints to stdout
import time,datetime

while True:
    print(datetime.datetime.now().time())
    time.sleep(1)
{% endhighlight %}


Using [*GNU Debugger*](https://www.gnu.org/software/gdb/) you can re-attach to the process, then invoke the creation of a logfile and duplicate the file descriptor to make the system send the data to the new file, instead of the terminal:

{% highlight bash %}
sudo gdb -p $(pidof python3) --batch -ex 'call creat("/tmp/stdout.log", 0600)' -ex 'call dup2(3, 1)'
{% endhighlight %}


note that you need to pass with the option **-p** the Process ID (PID) of the program; you can get it also via **ps -ef**
  
now, simply

{% highlight bash %}
tail -f /tmp/stdout.log
{% endhighlight %}

to get the output of the program.


