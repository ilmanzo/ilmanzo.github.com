---
layout: post
description: "A personal recap of Advent of Code 2024"
title: "Debriefing Advent of Code 2024"
categories: programming
tags: [programming, Rust, D, Crystal, performance, benchmark, algorithms]
author: Andrea Manzini
date: 2024-12-26
---

## 🎄 Intro 

After a very interesting and fun [SUSE hackweek](https://hackweek.opensuse.org/24/projects/hack-on-rich-terminal-user-interfaces), as every December since some years, I took part to [Advent of Code](https://adventofcode.com/).

First of all, I wish to thank [Eric Wastl](https://was.tl/) because he's giving us every year a great and unforgettable **advent**-ure.

![aoc_picture](/img/aoc2024.jpeg)
[image source: [Reddit](https://www.reddit.com/r/adventofcode/) [u/edo360](https://www.reddit.com/user/edo360/) ]

## 🎅 What's Advent of Code ?

More than just a countdown to Christmas, *AoC* is a joyful game that invites developers of all age and levels to sharpen their problem-solving abilities and coding skills. Like a virtual advent calendar, AoC presents a new programming puzzle each day from December 1st to 25th. These puzzles are often deceptively simple at first glance, but they quickly unfold into intricate challenges requiring clever algorithms and efficient code.

Over the years the number of people playing is steady increasing, with almost *300.000* users completing  at least one puzzle.
This year was so special because it's the 10th anniversary, so at the end I managed to complete **ALL** the puzzles and **reach 500 Stars!**

![500_stars](/img/aoc2024_stars.png)

## 🎁 Some Personal Highlights

As a deliberate choice, I solved most of the days using a mix of two languages: the [D Programming Language](https://dlang.org/) and the [Crystal Programming Language](https://crystal-lang.org/). 
I like to advocate those less-known languages and I think it would be a good occasion to spread some knowledge about them. If you are curious, you can find most of the solutions on [my github](https://github.com/ilmanzo/advent_of_code/tree/master/2024) repository, just be aware that this is **not** intended to be production-ready code, it's written just for fun at 6AM every morning and it's not following any best practice: on the opposite side it's my vacation and experiment time to play some dirty trick and write concise, almost unreadable code on purpose... You are warned 😅

If you understand Italian and want to hear me talking about Advent of Code I also had the pleasure to be a guest in a [podcast episode](https://pointerpodcast.it/p/pointer234-advent-of-code-grandmaster-con-andrea-manzini/) from the guys at [Pointer Podcast](https://pointerpodcast.it/) 🎙️. Highly recommended to subscribe!

Among all the 25 puzzles solved during the month, I can cite:

- [Day 1](https://adventofcode.com/2024/day/1) as the starting gives an easy start to be tackled with many different approaches
- [Day 3](https://adventofcode.com/2024/day/3) because it allows to familiarize yourself with regular expressions and some edge cases
- [Day 6](https://adventofcode.com/2024/day/6) as the first "grid" problem, easy but part2 not trivial; also resembles a mechanism already seen in some videogames
- [Day 7](https://adventofcode.com/2024/day/7) an easy one to upskill on recursion and backtracking
- [Day 8](https://adventofcode.com/2024/day/8) and [Day 13](https://adventofcode.com/2024/day/13) for playing with vector math 
- [Day 9](https://adventofcode.com/2024/day/9) for the idea to implement a very basic disk defragmenter 
- [Day 12](https://adventofcode.com/2024/day/12) gardening: weird shaped area and perimeter measurements 
- [Day 14](https://adventofcode.com/2024/day/14) moving robots: an unexpected plot twists on the second part!
- [Day 15](https://adventofcode.com/2024/day/15) instruct a robot to play a [sokoban](https://en.wikipedia.org/wiki/Sokoban) variant
- [Day 16](https://adventofcode.com/2024/day/16) and [Day 20](https://adventofcode.com/2024/day/20) maze puzzles with a "Race Condition" twist, where players can "glitch" trough some walls
- [Day 21](https://adventofcode.com/2024/day/21) where even the problem statement is recursive: you need to control a robot that controls another robot that controls a robot to press some buttons ... 
- [Day 23](https://adventofcode.com/2024/day/23) and [Day 24](https://adventofcode.com/2024/day/24) two classic theory problems about [graphs](https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm) and boolean logic
- [Day 25](https://adventofcode.com/2024/day/25) a final easy one that can be solved in many ways, with special attention to performance optimization

According to [Leaderboard times](https://aoc.xhyrom.dev/), the most difficult days where [15](https://adventofcode.com/2024/day/15), [17](https://adventofcode.com/2024/day/17), [21](https://adventofcode.com/2024/day/21) and [24](https://adventofcode.com/2024/day/24). I totally agree, go check them if you like hard challenges 😁 

## ☃️ Final thoughts

Whether you're a seasoned developer or just starting your coding journey, [Advent of Code](https://adventofcode.com/) offers a unique and rewarding experience. Beyond the satisfaction of solving intricate puzzles, it's an opportunity to explore new programming languages, optimize your code for efficiency, and learn from a vibrant community of fellow developers.  So, embrace the holiday spirit, grab your favorite programming language, and dive into the captivating world of Advent of Code.  Who knows, you might just discover a new trick or two along the way!

As this year's advent finished, the puzzles are still online: you can try and solve them at anytime.

*ps:*
If you are interested in Rust and crazy performance optimization, I can recommend to checkout [Advent of CodSpeed](https://codspeed.io/advent) 🐇 

