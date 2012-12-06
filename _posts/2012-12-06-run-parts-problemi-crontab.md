---
layout: post
title: "run-parts e problemi di crontab"
description: ""
category:
tags: [linux, tips, problemi, cron]
---
{% include JB/setup %}

Mi è capitato di inserire degli script nelle varie directory
/etc/cron.daily, /etc/cron.weekly
ma di scoprire che questi script non vengono eseguiti.
Il motivo è che il run-parts usato nelle Debian e derivate ignora i file che contengono un "." (e quindi tutti quelli con l'estensione)

Questo comportamento è [documentato](http://www.oreillynet.com/linux/blog/2007/08/runparts_scripts_a_note_about.html) anche nella man page, e previene alcuni inconvenienti come l'esecuzione dei **.bak** ma lo scrivo anche qui per ricordarmelo ... E forse potrà essere utile a qualcun altro :)
