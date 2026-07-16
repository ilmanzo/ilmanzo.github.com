---
layout: post
title: "Resoconto dello Zig Day 2026"
description: "Un piccolo resoconto dopo l'evento di programmazione"
categories: conference
tags: [linux, opensource, conferences, networking, social, programming, zig]
author: Andrea Manzini
date: 2026-02-22
---

# Intro

Ieri, 21 febbraio, ho avuto il piacere di partecipare allo [**Zig Day Milano 2026**](https://zig.day/europe/milano/), un fantastico evento dedicato al linguaggio di programmazione Zig. È stata una giornata intensa ricca di apprendimento, programmazione e incontri con persone fantastiche nella splendida cornice di Seregno (Milano).

![banner](/img/zigday2026/zigdaybanner.png)

## ⚡ Cos'è Zig?

Per chi ancora non lo conoscesse, [Zig](https://ziglang.org/) è un linguaggio di programmazione general-purpose e una toolchain per sviluppare software robusto, ottimizzato e riutilizzabile. Viene spesso visto come un moderno successore del C, ma offre molto di più.

Alcuni dei suoi principali vantaggi che spiccano particolarmente sono:

*   **Nessun flusso di controllo nascosto**: se sembra una chiamata di funzione, allora si tratta di una chiamata di funzione. Nessuna sorpresa legata all'overload degli operatori.
*   **Nessuna allocazione di memoria nascosta**: hai il pieno controllo della memoria. Se una funzione ha bisogno di allocare memoria, di solito accetta un allocatore come parametro.
*   **Comptime**: una potente funzionalità che consente di eseguire codice Zig durante la compilazione. Sostituisce la necessità di preprocessori o macro e permette la programmazione generica in modo estremamente leggibile.
*   **Interoperabilità con il C**: è possibile includere direttamente file header C e fare il link con librerie C senza alcuno sforzo.
*   **Cross-compilazione**: il sistema di build `zig build` rende la compilazione incrociata per diverse architetture incredibilmente semplice.

## 🥐 Mattina: il Crash Course

La giornata è iniziata nel migliore dei modi: con un'ottima colazione! Caffè e brioche sono stati il carburante ideale per dare il via alle attività.

La sessione mattutina è stata guidata da [**Loris Cro**](https://kristoff.it/), VP of Community presso la [Zig Software Foundation](https://ziglang.org/zsf/). Ci ha offerto un "crash course" sul linguaggio, approfondendo la filosofia alla base di Zig, la sintassi fondamentale e alcune delle caratteristiche uniche che lo contraddistinguono. È stato fantastico ascoltare le considerazioni di chi è coinvolto in prima persona nello sviluppo del linguaggio.

## 🍝 Pranzo e Networking

Dopo aver assimilato tutte queste informazioni, abbiamo fatto una pausa per il pranzo. È stata l'occasione perfetta per chiacchierare con gli altri partecipanti, discutere di quanto appreso e gustare un'ottima pizza.

![code](/img/zigday2026/code.jpg)


## 💻 Pomeriggio: Happy Hacking

Il pomeriggio è stato dedicato all'hacking libero. Ci siamo divisi in gruppi o abbiamo lavorato individualmente su progetti open source.

Ho deciso di mettermi alla prova con [**ziglings**](https://codeberg.org/ziglings/exercises), un progetto che insegna la sintassi e i concetti di Zig attraverso una serie di programmi volutamente errati da correggere. È un ottimo modo per imparare facendo, e lo consiglio vivamente a chiunque stia iniziando con Zig.

È stato stimolante vedere tutti concentrati, pronti ad aiutarsi a vicenda e impegnati a creare progetti interessanti.

## 🍕 Sera: Condivisione e Cena

Al tramonto ci siamo riuniti per condividere i progressi compiuti. È stata una sessione di "show and tell" in cui i partecipanti hanno presentato i propri lavori pomeridiani. Dai semplici esercizi fino a strumenti più complessi, è stato davvero impressionante vedere cosa si può realizzare in poche ore.

Abbiamo concluso l'evento con una cena, continuando le nostre conversazioni e festeggiando una giornata decisamente produttiva.

![sticker](/img/zigday2026/sticker.jpeg)


## Conclusione

Lo Zig Day Milano è stato un successo strepitoso. Se avete l'opportunità di partecipare a un evento Zig vicino a voi, non lasciatevela sfuggire! Si tratta di una community accogliente con uno stack tecnologico davvero entusiasmante.

Buona programmazione! 🦎