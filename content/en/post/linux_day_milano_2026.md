---
layout: post
title: "Linux Day Milano 2026 recap"
description: "Recap of my talk 'A scatola chiusa: Test Coverage di binari nativi con eBPF' at Linux Day Milano 2026"
categories: conference
tags: [linux, opensource, conferences, networking, ebpf, testing, coverage]
author: Andrea Manzini
date: 2026-11-02
cover:
  image: "/img/linux-day-2026-badge.jpg"
  alt: "Linux Day Milano 2026 Badge"
  caption: "Linux Day Milano 2026"
---

# Intro

On Saturday, October 24th, 2026, I had the pleasure of attending [**Linux Day Milano 2026**](https://linuxdaymilano.org/).

For those unfamiliar with it, [**Linux Day**](https://www.linuxday.it/) is the premier nationwide event in Italy dedicated to GNU/Linux, Free Software, and open culture. Promoted annually since 2001 by the **[Italian Linux Society (ILS)](https://www.ils.org/)** on the fourth Saturday of October, it is held simultaneously across dozens of Italian cities thanks to local Linux User Groups (LUGs), student groups, and passionate volunteers. It remains the most important grassroots gathering for open source enthusiasts and professionals in the country.

## 🎙️ The Talk: A scatola chiusa — Test Coverage di binari nativi con eBPF

At 11:45 in track T.1.1, I gave my talk: *"A scatola chiusa: Test Coverage di binari nativi con eBPF"* ([schedule](https://linuxdaymilano.org/schedule/)).

Measuring how much code is actually executed during integration testing is easy if you own the source and can rebuild with coverage instrumentation. But what happens when dealing with closed legacy binaries, third-party software, or entire system distributions where recompiling is out of the question? Traditional instrumentation tools like Valgrind or Intel PIN introduce heavy slowdowns (5–20×) or proprietary toolchains.

In this session, I discussed how modern Linux **eBPF** features (particularly `uprobe_multi` and in-kernel first-call deduplication) change the rules of the game. I demonstrated [**funkoverage**](https://github.com/ilmanzo/BinaryCoverage), an open-source pure-Go tool that captures function-level test coverage on any native ELF binary with virtually zero overhead (< 2%). We went through live demonstrations tracing standard system binaries, illustrating how kernel tracing empowers modern black-box QA on native software.

*(If you missed the earlier technical deep dive, feel free to check out my related post: [How much code are you testing? Part 4](/post/measuring-test-coverage-with-ebpf/)).*

## 📊 Slides

The presentation slides are available for download:

👉 **[Download Slides (PDF)](/files/linux_day_milano_2026_binary_coverage.pdf)**

## ❤️ Thanks

A heartfelt thank you to the **Italian Linux Society (ILS)** and all the organizers and volunteers of Linux Day Milano for hosting such an energetic and well-run event. Community conferences like this are what keep the free and open source spirit alive and thriving!
