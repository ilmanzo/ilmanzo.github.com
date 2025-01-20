---
layout: post
description: "An utility to simplify monitoring openqa job clones"
title: "Writing shell filters for fun and profit"
categories: programming
tags: [programming, Rust, shell, command line, openqa, testing]
author: Andrea Manzini
date: 2025-01-19
---

## Why ? 

During my daily job I have sometimes to debug failed [openqa test jobs](https://open.qa/). 

One of the testing mantra is to [reproduce the issue](https://www.testdevlab.com/blog/issue-reproduction-why-reproducing-bugs-matter) and for that task the openqa community has [developed some tooling](https://github.com/os-autoinst/scripts). 

In practice, I often have some output like this one below from some job cloning operations:

```
Cloning parents of sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit
1 job has been created:
 - sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit -> https://openqa.suse.de/tests/16425390
Cloning parents of sle-15-SP5-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit
1 job has been created:
 - sle-15-SP5-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit -> https://openqa.suse.de/tests/16425391
Cloning parents of sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit
1 job has been created:
 - sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit -> https://openqa.suse.de/tests/16425392
```

And when I want to monitor those jobs, I'd need to copy-paste all the job URLs and pass them as arguments to the cool [openqa-mon](https://github.com/os-autoinst/openqa-mon) utility which will show and notify me of the job status in the terminal.

```bash
$ openqa-mon https://openqa.suse.de/tests/16425390+2
```

Imagine having to monitor 50 openQA jobs simultaneously. Manually copying and pasting each URL from the console output into openqa-mon is time-consuming and error-prone. This quickly becomes a bottleneck in my workflow.

## Init 

While openQA offers a web interface for monitoring jobs, I prefer the terminal-based workflow of `openqa-mon` for its flexibility and scripting capabilities. However, even with `openqa-mon`, manually gathering the URLs remains a pain point.

As a lazy person, I'm always asking myself: Can I automate this? Whenever I find myself doing the same thing two or three times. 
Of course we can. Shall we do it in Rust :crab: ? Well, why not ? Maybe I will learn something in the process :smile:

```
$ cargo init oqa-jobfilter
```

![crab-shell](/img/pexels-taryn-elliott-6405711.jpg)
Image credits to: [@taryn-elliott](https://www.pexels.com/@taryn-elliott/)

The complete project is available on [GitHub](https://github.com/ilmanzo/oqa-jobfilter) and it's MIT licensed.

## Problem statement

1. The program should act as a shell filter, taking input via stdin and outputting via stdout: `$ openqa-clone-job <myjobs> | oqa-jobfilter`
2. The program should be testable: I want to develop it using a Test-Driven development process, which allows me to change its design and inner architecture while maintaining the same behavior
3. output should be in order and ready to be passed as an `openqa-mon` invocation as-is
4. output should be as compact as possible, so for example when I have consecutive test IDs like https://openqa.suse.de/tests/1201, https://openqa.suse.de/tests/1202, https://openqa.suse.de/tests/1203, https://openqa.suse.de/tests/1204 I can simply send 1201+3 to `openqa-mon` . Likewise, different job IDs for the same openQA instance can be grouped with a comma separate, so when I have some cloned tests like https://openqa.suse.de/tests/1201, https://openqa.suse.de/tests/1207, https://openqa.suse.de/tests/1210, https://openqa.suse.de/tests/1215 should become


```bash
openqa-mon https://openqa.suse.de 1201,1207,1210,1215
```

## Implementation details

Rust concept of [`Traits`](https://doc.rust-lang.org/book/ch10-02-traits.html) is essential to fullfill requisite #1 and #2. This mean we will not write a function asking for a parameter of a specific type, but we will accept **any** type that implements those Read/Write behavior. This is similar to [interfaces](https://go.dev/tour/methods/9) from Go (or abstract classes in object oriented languages) and it's a very powerful programming paradigm. 

So our main will read and write from stdin/stdout, while the real computing function will just read/write from/to a "generic" reader/writer. In this way we can also test the function by passing dummy inputs and inspecting outputs.

```Rust
pub fn process_input<R: Read, W: Write>(input: R, mut output: W) -> io::Result<()> {
```

Requisite #3: Ordering, [de-duplication](https://doc.rust-lang.org/std/vec/struct.Vec.html#method.dedup), and formatting are handled by features included in the comprehensive Rust standard library.

Requisite #4 is the trickiest: to implement the consecutive-id checking and same-domain grouping we need to store each job into a proper data structure

```Rust
pub struct OpenQAJob {
    pub domain: Domain,
    pub id: u32,
    pub consecutive_count: u32,
}
```
which at this point deserves to be placed in a separate source file. It's a good occasion to learn how to organize a Rust project and modelling of "Domain Objects". Note that each `OpenQAJob` have associated functions (very similar to "methods"). 

## Some fancy stuff

- I tried to make use of some Rust language feature as well:
  - [constant evaluation at compile time](https://doc.rust-lang.org/reference/const_eval.html)
  - the code is organized and split in logically separated source files
  - the ["clippy" linter](https://github.com/rust-lang/rust-clippy) is configured as picky as possible
  - documentation comments: we can easily extract documentation directly from the source code
  - unit testing to cover all the cases and enable a fearless refactoring

- As a bonus, I added a GitHub action to run unit tests and compile the project at each commit+push; ready for a proper release cycle.

## Closing words

Creating this program was a quick and dirty hacking session, so there are for sure some improvement opportunities: if you want to contribute feel free to contact me and/or file issues or pull requests. Enjoy!


