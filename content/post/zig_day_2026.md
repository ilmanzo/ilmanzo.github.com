---
layout: post
title: "Zig Day 2026 recap"
description: "Small debriefing after coding event"
categories: conference
tags: [linux, opensource, conferences, networking, social, programming, zig]
author: Andrea Manzini
date: 2026-02-22
---

# Intro

Yesterday, February 21st, I had the pleasure of attending [**Zig Day Milan 2026**](https://zig.day/europe/milano/), a fantastic event dedicated to the Zig programming language. It was a full day of learning, coding, and meeting great people in the beautiful city of Seregno(Milan)

![banner](/img/zigday2026/zigdaybanner.png)

## ⚡ What is Zig?

For those who might not know, [Zig](https://ziglang.org/) is a general-purpose programming language and toolchain for maintaining robust, optimal, and reusable software. It's often seen as a modern successor to C, but it brings so much more to the table.

Some of its key advantages that really shine are:

*   **No hidden control flow**: If it looks like a function call, it is a function call. No operator overloading surprises.
*   **No hidden memory allocations**: You control the memory. If a function needs to allocate memory, it usually takes an allocator as a parameter.
*   **Comptime**: A powerful feature that allows you to run Zig code during compilation. It replaces the need for a preprocessor or macros and enables generic programming in a very readable way.
*   **C Interop**: You can include C header files directly and link against C libraries effortlessly.
*   **Cross-compilation**: The `zig build` system makes cross-compiling for different architectures incredibly simple.

## 🥐 Morning: The Crash Course

The day started in the best possible way: with a nice breakfast! Coffee and pastries were the fuel we needed to kick off the activities.

The morning session was led by [**Loris Cro**](https://kristoff.it/), VP of Community at the [Zig Software Foundation](https://ziglang.org/zsf/). He gave us a "crash course" on the language, covering the philosophy behind Zig, the basic syntax, and some of the unique features that make it stand out. It was great to get insights directly from someone so involved in the language's development.

## 🍝 Lunch & Networking

After soaking up all that information, we took a break for lunch. It was a perfect opportunity to chat with other attendees, discuss what we learned, and enjoy some good pizza.

![code](/img/zigday2026/code.jpg)


## 💻 Afternoon: Happy Hacking

The afternoon was dedicated to free hacking. We split into groups or worked individually on open source projects.

I decided to get my hands dirty with [**ziglings**](https://codeberg.org/ziglings/exercises), a project that teaches Zig syntax and concepts through a series of broken programs that you have to fix. It's an excellent way to learn by doing, and I highly recommend it to anyone starting with Zig.

It was inspiring to see everyone focused, helping each other out, and building cool stuff.

## 🍕 Evening: Sharing & Dinner

As the sun set, we gathered to share our advancements. It was a "show and tell" session where people presented what they worked on during the afternoon. From small exercises to more complex tools, it was impressive to see what can be achieved in just a few hours.

We wrapped up the event with a dinner, continuing the conversations and celebrating a productive day.

![sticker](/img/zigday2026/sticker.jpeg)


## Conclusion

Zig Day Milan was a blast. If you have the chance to attend a Zig event near you, don't miss it! It's a welcoming community with a very exciting technology stack.

Happy coding! 🦎

