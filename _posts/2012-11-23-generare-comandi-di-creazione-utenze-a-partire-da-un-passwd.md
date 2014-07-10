---
layout: post
title: "generare comandi di creazione utenze a partire da un passwd"
description: ""
category: sysadmin
tags: [linux, command line, scripting, awk, automation]
---
{% include JB/setup %}

A volte e' necessario replicare le utenze con gli stessi parametri su piu' server linux diversi.

Perche' farlo a mano ? Se sono tanti e' un lavoro noioso e potremmo anche commettere degli errori.

Ecco un semplice *one-liner* che fa il parsing di un file **/etc/passwd** e genera
i corrispondenti comandi **useradd**

    awk -F: '{printf "useradd -m -u%s -g%s -d%s -s%s %s\n" , $3,$4,$6,$7,$1}' /etc/passwd

Ovviamente l'output puo' essere comodamente filtrato con grep, usato via copy&paste, inserito in uno script, eccetera...
