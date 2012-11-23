---
layout: post
title: "generare comandi di creazione utenze a partire da un passwd"
description: ""
category:
tags: [linux, command line, scripting, awk, automation]
---
{% include JB/setup %}

A volte è necessario replicare le utenze con gli stessi parametri su più server linux diversi.

Perché farlo a mano ? Se sono tanti è un lavoro noioso e potremmo anche commettere degli errori.

Ecco un semplice *one-liner* che fa il parsing di un file **/etc/passwd** e genera
i corrispondenti comandi **useradd**

    awk -F: '{printf "useradd -m -u%s -g%s -d%s -s%s %s\n" , $3,$4,$6,$7,$1}' /etc/passwd

Ovviamente l'output può essere comodamente filtrato con grep, usato via copy&paste, inserito in uno script, eccetera...
