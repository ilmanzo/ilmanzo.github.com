---
layout: post
title: "Ventole silenziose su Thinkpad P15"
description: "Come ridurre il rumore predefinito delle ventole su Thinkpad P15 Gen2"
categories: hardware
tags: [linux, desktop, sysadmin, thinkpad, fan, noise]
author: Andrea Manzini
date: 2023-09-01
---

## Intro

Il portatile `Thinkpad P15` è un'ottima macchina Linux, ma c'è un dettaglio fastidioso, come scrive la [Wiki di Arch](https://wiki.archlinux.org/title/Lenovo_ThinkPad_P15_Gen_1):
*"Il funzionamento predefinito delle ventole è rumoroso, poiché sono praticamente sempre a media potenza. Il programma thinkfan può essere utilizzato per ottenere un funzionamento più silenzioso, pur mantenendo temperature ragionevoli."* . Rendiamolo più silenzioso.

## Prerequisiti

Installare il pacchetto rpm `thinkfan` e abilitare il demone:
```shell
# zypper in thinkfan && systemctl enable --now thinkfan
```
Assicurarsi che i moduli vengano caricati all'avvio con le opzioni per sovrascrivere il controllo delle ventole e abilitare le funzionalità sperimentali:
```shell
$ cat /etc/modules-load.d/thinkpad.conf
thinkpad_acpi
coretemp

$ cat /etc/modprobe.d/thinkpad_acpi.conf
options thinkpad_acpi fan_control=1 experimental=1
```

## Configurazione

La configurazione del demone consiste in un singolo e breve file. Nella prima parte dobbiamo specificare il `virtual file` contenente le temperature; poi il file che controlla la velocità della ventola, e una terza sezione che mappa il `livello della ventola` (fan level) all'intervallo di temperatura:

```shell
$ cat /etc/thinkfan.conf 
sensors:
  - tpacpi: /proc/acpi/ibm/thermal
    # Alcune delle voci di temperatura in /proc/acpi/ibm/thermal potrebbero essere
    # irrilevanti o inutilizzate, quindi è possibile selezionare quelle singole:
    indices: [1, 2, 4, 5, 6]

fans:
  - tpacpi: /proc/acpi/ibm/fan

levels:
  - [0, 0, 60]
  - [2, 60, 65]
  - [3, 65, 70]
  - [5, 70, 75]
  - [6, 75, 80]
  - [7, 80, 85]
  - ["level disengaged", 85, 255]
```

## Conclusione

A seconda del vostro sistema, potete utilizzare [molti altri programmi](https://wiki.archlinux.org/title/fan_speed_control) per controllare la velocità delle ventole in Linux; thinkfan ha il vantaggio di essere leggero e altamente configurabile.
