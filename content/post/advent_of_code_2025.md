---
layout: post
description: "Having fun with Christmas code challenges"
title: "Advent of code 2025: the diaries"
categories: programming
tags: [hackweek, programming, algorithms, quiz, challenges]
author: Andrea Manzini
date: 2025-12-01
---

## 🎄 Intro 

It is December, the most wonderful time of the year for programmers. But as we log in for [Advent of Code (AoC) 2025](https://adventofcode.com/2025 ), you might notice the atmosphere is a little different. We passed a decade of Eric Wastl’s incredible work, and with this milestone comes a significant shift in tradition.

Before diving into solutions, I want to take a moment to reflect on the state of AoC this year, the changes we are seeing, and why—despite everything—we keep coming back to the terminal.

### The 2025 Format Changes
If you are looking for the Global Leaderboard or preparing for a 25-day marathon, you have likely noticed two major adjustments:

- No Global Leaderboard: The competitive rush has been removed this year.
- A 12-Day Calendar: Instead of the usual 25 days, the event runs for 12 days.

While these changes might feel surprising to veterans, they come with a message of empathy. Maintaining a project of this magnitude for ten years is a grueling, massive commitment. Eric has consistently operated on a whole other level to bring us these elegant, funny, and creative challenges. Acknowledging the "human cost" of this event means supporting the creator’s need to protect his time and mental health.

### Why We Still Solve
In 2025, amid the noise of AI and code assistants, a valid question arises: *"Why bother solving puzzles when an AI can do it in seconds?"*

The answer is simple: People still go to musicals and live concerts even though Spotify exists.

We don’t do Advent of Code because it is the "efficient" way to get an answer. We do it because *we want to solve the puzzle*. We do it for the thrill, the frustration, and the learning. AoC is a way to reconnect with the simple love of programming. It caters to every level, from the beginner just starting out to the seasoned dev looking for a spark.

### A Generational Tradition
Whether it is 25 days or 12 days, Advent of Code has become a tradition as strong as Star Wars for many of us. It is something to pass down; there are children today wearing AoC pajamas, growing up with these puzzles as a holiday staple.

So, to [Eric](https://was.tl/): Thank you for the last 10 years. We are here for the puzzles, the community, and the tradition—in whatever format works for you.

Now, let's open up the editor and solve Day 1. SPOILER ALERT! 

## ✨ [Day 1](https://adventofcode.com/2025/day/1)

Oh no, apparently Elves have discovered Project Management! (I suspect this to be an hint about the reduced number of stars this year, did [Eric](https://was.tl/) switch role?)

You have a safe with 100-positions dial (0 to 99), and istructions to rotate Left and Right a number of time : `L68 L30 R48 L5 R60 L55 L1 L99 R14 L82` and so on. Initial dial position is 50. In the first part, you need to count how many times the dial STOPS exactly at number 0; on the second part (revealed after 1st solution) you need to count how many times it PASSED by the 0 number. 

![day01](/img/aoc2025/day01.gif)
(animation courtesy of https://www.reddit.com/user/Ok-Curve902/)

Here an elegant solution in AWK:
```awk
BEGIN { p = 50 }
{
    c = substr($0, 2)
    p = (p + (substr($0, 1, 1) == "R" ? c : 100 - c)) % 100
    n += !p
}
END { print n }
```
This takes advantage of modular arithmetic: rotating Left by N is equivalent to rotate Right by 100-N.

## 🎁 [Day 2](https://adventofcode.com/2025/day/2)

Some young elves played with the gift shop computer and messed up the product ids! 

You are given a list of ranges, like `11-22,95-115,998-1012,1188511880-1188511890,222220-222224,
1698522-1698528,446443-446449,38593856-38593862,565653-565659,
824824821-824824827,2121212118-2121212124` and you must find out the one that are not valid ids.

For part1 , the invalid ids are the ones that repeats exactly twice, like `11` or `123123`. For part2, they can repeat twice or more, like `131313` 

![day02](/img/aoc2025/day02.gif)
(animation courtesy of https://www.reddit.com/user/Boojum/)

Given the problem is all about filtering a list, I reached for some *functional style* . The [D Programming Language](https://dlang.org/) has nice features:

{{< highlight D >}} 
bool isInvalidId1(string id) {
    auto mid = id.length / 2;
    return id.length > 0 && id.length % 2 == 0 && id[0 .. mid] == id[mid .. $];
}

bool isInvalidId2(string id) {
    auto m = id.length;
    foreach (k; 2 .. m + 1)
    {
        if (m % k == 0)
        {
            auto firstToken = id[0 .. m / k];
            if (firstToken.replicate(k).equal(id)) return true;
        }
    }
    return false;
}

void main() {
    auto ranges = stdin.readln().strip.split(',').map!(pair => pair.split('-').map!(to!long));
    auto numbers = ranges.map!(r => iota(r[0], r[1] + 1).map!(to!string)).joiner;
    writeln(numbers.filter!isInvalidId1.map!(to!long).sum);
    writeln(numbers.filter!isInvalidId2.map!(to!long).sum);
}
{{</ highlight >}}


BTW this problem is interesting because it can be tackled in many ways: string comparison, regular expressions, and purely arithmetic.
We can also notice that our input range is limited, e.g. the biggest numbers are ten digits. This means that the possible ways to "repeat" any digit pattern are limited as well.

## 🔋 [Day 3](https://adventofcode.com/2025/day/3)

You need to reach the lower floors, but unfortunately the elevators are out of power. Today's problem is about connecting together some batteries to get the most "Joltage" out of them.
So you have four battery packs, represented here by the following lines:

```
987654321111111
811111111111119
234234234234278
818181911112111
```

for each pack, you want to find the greatest number you can get by connecting two batteries, for example on the first row, the `9` and the `8` gives `98`.

![day01](/img/aoc2025/day03.gif)
(animation courtesy of https://www.reddit.com/user/danmaps/)


[SPOILER] 

On the second part you'll need to connect 12 batteries.

[SPOILER] 

Today's solution in Nim (I'll publish here just part1, you can find [part2 on my repo](https://github.com/ilmanzo/advent_of_code/tree/master/2025/day03))

{{< highlight nim >}} 
template benchmark(code: untyped) =
  block:
    let t0 = getMonoTime()
    code
    let elapsed = getMonoTime() - t0
    echo "Time ", elapsed.inMilliseconds(), " ms"

proc part1(data: seq[int]): int =
  for i in 0 ..< data.len - 1:
    let currentVal = 10 * data[i] + data[i + 1 .. ^1].max
    result = max(result, currentVal)

var input: seq[seq[int]]
for line in stdin.lines:
  input.add line.map(proc(c: char): int = parseInt($c))

benchmark:
  echo "Part 1: ", input.map(part1).sum
{{</ highlight >}}

The algorithm is straightforward: for each digit, pair it with the biggest subsequent one. The pair is a candidate to become the new maximum.

A couple of observations about the Nim language, which in my opinion has a lot of potential:
- I like how you can easily write templates (see the benchmark at the top) and how they seamlessly integrate with the language syntax
- the special `result` variable is handy for any calculation and automatically returned at the end of the function
- the program compile to very fast native binary: using the real 100x200 input, the program outputs the correct value in ~2 milliseconds.


<!-- ## 🎅 [Day 4](https://adventofcode.com/2025/day/4) -->

## ☃️ Notes and references

I will collect here all the links and references or related things to AoC25

(warning: there might be commercial offers)
- Advent of DevOps: https://sadservers.com/advent
- Advent of Cyber: https://tryhackme.com/adventofcyber25
- AoC in Kotlin: https://blog.jetbrains.com/kotlin/2025/11/advent-of-code-in-kotlin-2025/