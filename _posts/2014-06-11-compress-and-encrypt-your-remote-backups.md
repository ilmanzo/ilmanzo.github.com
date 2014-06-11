---
layout: post
title: "Compress and encrypt your [remote] backups"
description: "How to securely backup your files in a remote location"
category: sysadmin
tags: [linux, backup, sysadmin]
---
{% include JB/setup %}


To backup your data is secure, but for better security let's encrypt your
backups!


to compress and encrypt with 'mypassword':
{% highlight bash %}
tar -Jcf - directory | openssl aes-256-cbc -salt -k mypassword -out backup.tar.xz.aes
{% endhighlight %}

to decrypt and decompress:
{% highlight bash %}
openssl aes-256-cbc -d -salt -k mypassword -in directory.tar.xz.aes | tar -xJ -f - 
{% endhighlight %}

Another trick with the tar command is useful for remote backups:
{% highlight bash %}
tar -zcvfp - /wwwdata | ssh root@remote.server.com "cat > /backup/wwwdata.tar.gz"
{% endhighlight %}




