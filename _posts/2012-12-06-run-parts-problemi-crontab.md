---
layout: post
title: "run-parts e problemi di crontab"
description: ""
category:
tags: [linux, tips, problemi, cron]
---
{% include JB/setup %}

Mi capita spesso di inserire degli script nelle varie directory
/etc/cron.daily, /etc/cron.weekly
ma di scoprire che questi script non vengono eseguiti.
Il motivo è che il run-parts usato nelle Debian e derivate ignora i file che contengono un "." (e quindi tutti quelli con l'estensione)
Questo comportamento è documentato nella man page, ma lo scrivo qui per ricordarmelo ... E forse potrà essere utile a qualcun altro :)
