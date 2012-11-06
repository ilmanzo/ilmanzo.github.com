---
layout: post
title: "background tasks in Ruby e linux"
description: ""
category:
tags: [linux, ruby]
---
{% include JB/setup %}

A volte negli script Ruby ho bisogno di controllare l'esecuzione di un comando eseguito in modalità asincrona, ho creato pertanto una classe apposita:

<script src="https://gist.github.com/4017156.js"> </script>

come si usa ? Molto semplice:

    wg = BackgroundJob.new 'wget http://www.google.it'
    sleep 10
    wg.stop!

ovviamente non bisogna abusarne ;-)
