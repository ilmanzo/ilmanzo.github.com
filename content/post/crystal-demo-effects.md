---
layout: post
title: "Old-School demo effects with Crystal"
description: "revisiting old code with a new programming language"
categories: programming
tags: [programming, 'crystal lang', crystal, graphics, demoscene ]
author: Andrea Manzini
date: 2023-05-18
---

Nostalgia time! Today I decided to play with [Raylib](https://www.raylib.com/index.html) and the [Crystal Programming Language](https://crystal-lang.org/). 

Technically speaking, the "plasma" effect is just a two variables noise function. Some used [Perlin Noise](https://en.wikipedia.org/wiki/Perlin_noise), others the [Diamond-square](https://en.wikipedia.org/wiki/Diamond-square_algorithm) algorithm. A more interesting pattern can be obtained with trigonometrical functions, as explained [here](https://lodev.org/cgtutor/plasma.html).

The interesting part here is the easyness of graphics programming in a Linux environment with a high level, yet performant and statically typed programming language.

The code is straightforward and a simple port of the original 'C' source, I got surprised how the [Crystal Language](https://crystal-lang.org/) is easy to use and produces a quite fast native binary. If you want to check it out, you can find on my [github account](https://github.com/ilmanzo/plasmademo); in the meantime enjoy the mandatory video/screenshot :)

{{< video src="/img/plasma.mp4" type="video/mp4" preload="auto" >}}

p.s. Thanks to [Ian Rash](https://github.com/sol-vin/raylib-cr) who created the awesome bindings! 