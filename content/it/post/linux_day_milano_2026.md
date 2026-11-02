---
layout: post
title: "Resoconto del Linux Day Milano 2026"
description: "Breve debriefing e slide del talk 'A scatola chiusa: Test Coverage di binari nativi con eBPF' al Linux Day Milano 2026"
categories: conference
tags: [linux, opensource, conferences, networking, ebpf, testing, coverage]
author: Andrea Manzini
date: 2026-11-02
cover:
  image: "/img/linux-day-2026-badge.jpg"
  alt: "Badge del Linux Day Milano 2026"
  caption: "Linux Day Milano 2026"
---

# Intro

Sabato 24 ottobre 2026 ho partecipato al [**Linux Day Milano 2026**](https://linuxdaymilano.org/).

Il [**Linux Day**](https://www.linuxday.it/) è la principale manifestazione italiana dedicata a GNU/Linux, al software libero e alla cultura aperta. Promossa a livello nazionale dal 2001 da **[Italian Linux Society (ILS)](https://www.ils.org/)** ogni quarto sabato di ottobre, la giornata si tiene in contemporanea in decine di città italiane grazie all'impegno di Linux User Group (LUG), studenti e volontari. È il punto d'incontro per eccellenza per appassionati, curiosi e professionisti del mondo open source in Italia.

## 🎙️ Il Talk: A scatola chiusa — Test Coverage di binari nativi con eBPF

Alle 11:45 nell'aula T.1.1 ho tenuto il mio intervento: *"A scatola chiusa: Test Coverage di binari nativi con eBPF"* ([programma](https://linuxdaymilano.org/schedule/)).

Misurare quanto codice viene effettivamente eseguito durante i test di integrazione è semplice se si possiedono i sorgenti e si può ricompilare con i flag di profilazione. Ma cosa succede se bisogna testare binari legacy chiusi, strumenti di terze parti o un intero ambiente di sistema in cui la ricompilazione è impossibile o impraticabile? Le soluzioni tradizionali di analisi dinamica come Valgrind o Intel PIN introducono un rallentamento notevole (da 5 a 20 volte) o richiedono framework proprietari.

Nel corso della sessione ho illustrato come le recenti funzionalità del kernel Linux per **eBPF** (in particolare `uprobe_multi` e la deduplicazione della prima chiamata direttamente nel kernel) cambino radicalmente lo scenario. Ho presentato [**funkoverage**](https://github.com/ilmanzo/BinaryCoverage), uno strumento open-source scritto in Go che permette di raccogliere la copertura a livello di singola funzione su qualunque binario ELF non modificato, con un overhead trascurabile (< 2%). Abbiamo visto dal vivo il tracciamento su binari standard di sistema, dimostrando come sia possibile fare QA moderno a "scatola chiusa" anche su software nativo.

*(Se vi siete persi gli articoli tecnici di approfondimento sul tema, potete leggere la guida completa: [How much code are you testing? Parte 4](/it/post/measuring-test-coverage-with-ebpf/)).*

## 📊 Slide

Le slide della presentazione sono disponibili per il download:

👉 **[Scarica le Slide (PDF)](/files/linux_day_milano_2026_binary_coverage.pdf)**

## ❤️ Ringraziamenti

Un grandissimo ringraziamento va a **Italian Linux Society (ILS)** e a tutti gli organizzatori e volontari del Linux Day Milano per l'eccellente lavoro svolto nell'organizzare questa edizione. Eventi comunitari e non commerciali come questo sono il vero motore del software libero!
