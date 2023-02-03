---
layout: post
title: "a SUSE hackweek22 report"
description: "writeup about learnings and achievements in last hackweek"
categories: hacking
tags: [linux, programming, testing, nim, container]
author: Andrea Manzini
date: 2023-02-03
---

This February I decided to participate in the [SUSE Hackweek](https://hackweek.opensuse.org/). 

<!--more-->

Hack Week is the time SUSE employees experiment, innovate & learn interruption-free for a whole week! Across teams or alone, but always without limits.
A SUSE tradition since 2007, Hack Week has brought together hundreds of hackers around the globe to collaborate on open source. Learn more about Hack Week [here](https://hackweek.opensuse.org/about)

My project has two purposes: 
  - play with the [Nim programming language](https://nim-lang.org/) advanced features like templates and macros
  - experiment with container generation

So I decided to write a simple library that lets you describe a container image with a DSL (Domain Specific Language) that mimics the declarative style that is standard for Dockerfile and Containerfile. The benefits of this approach are multiple : you have the compiler type checking that 

Usage is straightforward: you can basically mix Containerfile syntax with powerful Nim language contructs: variables, loops, arrays and anything you need

{{< highlight nim >}}
import containertools

let my_app="program.py" 

let image = container:
    FROM "opensuse/leap"
    WORKDIR "/opt"
    COPY my_app my_app
    CMD @["python3", my_app]

image.save "Containerfile"
image.build  
{{</ highlight >}}

I implemented everything using TDD (Test Driven Development/Design) and this approach made me rethink a lot of design decisions and refactoring, which maybe are evident in the [source code repository](https://github.com/ilmanzo/containertools).

The library also work in the opposite way: you can give it a Dockerfile and it will check for errors or suggest some possible optimizations, but this feature is only at the early stage. Further ideas can be to check the container for secret leaks, or check at runtime for issues like wrong images names or dangerous commands.
We could also generate different kind of declarative files formats, like yaml for kubenertes, CI/CD workflows and so on. 

If you are curious about the inner working, or want to take part in the development, feel free to get in contact.

I enjoyed HackWeek and this first Proof-of-concept implementation, looking forward for future improvements!



