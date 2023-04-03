---
layout: post
title: "Benchmarking a Rust function"
description: "A first look at Rust performance benchmarking"
categories: programming
tags: [programming, Rust, performance, benchmark ]
author: Andrea Manzini
date: 2023-04-02
---

Once in a while I like to play with [Advent Of Code](https://adventofcode.com/) problems :christmas_tree:. Today I decided to tackle an [easy one](https://adventofcode.com/2020/day/1) and, since the answer  was almost trivial to find, I wanted to go deeper and understand how to measure and improve the performance of the solution. 

<!--more-->

# Something About Us

In this first problem, they give you a long list of numbers; you need to find the two entries that sum to `2020` and then multiply those two numbers together.

For example, if numbers are the following:
```
1721
979
366
299
675
1456
```
The two entries that sum to `2020` are `1721` and `299`. Multiplying them together produces `1721 * 299` = `514579`.

Once solved in a brute-force way, I thought to take the occasion to learn how you can benchmark code in [Rust](https://www.rust-lang.org/) :crab:.

# Get Lucky

First of all, I wrote a quick and dirty solution directly in the `main.rs` file:

{{< highlight rust >}}
pub fn part1_1(input: &[usize]) -> usize {
    for i in input {
        for j in input {
            if i+j==2020 { 
                return i*j;
            }
        }
    }
    0
}

fn main() {
    let input=include_str!("../../input.txt")
    .lines()
    .map(|i| i.parse::<usize>().unwrap())
    .collect();
    println!("{}", part1_1(&input));
}
{{</ highlight >}}

Ugh... **Quadratic** complexity! Well, `cargo run` gives us a correct answer, which won't reveal here :wink: So we could call it a day and move to the next problem, or not ?

# Technologic

While it works as expected, that code isn't easily measurable. So we'd need to take out our function in a separate `crate` and edit our `Cargo.toml` accordingly:

{{< highlight toml >}}
[package]
name = "day01_rust"
version = "0.1.0"
edition = "2021"

[lib]
name = "day01"
path = "src/lib.rs"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]

[dev-dependencies]
criterion = "0.4.0"

[[bench]]
name = "benchmark"
harness = false
{{</ highlight >}}

With this setup, we can also factor out the code we want to measure in `src/lib.rs`: 

{{< highlight rust >}}
pub fn part1_1(input: &[usize]) -> usize {
    for i in input {
        for j in input {
            if i+j==2020 { 
                return i*j;
            }
        }
    }
    0
}

pub fn get_input() -> Vec<usize> {
    include_str!("../../input.txt")
    .lines()
    .map(|i| i.parse::<usize>().unwrap())
    .collect()
}
{{</ highlight >}}

While our `src/main.rs` will contain simply importing external functions and invocation:

{{< highlight rust >}}
use day01::{get_input, part1};

fn main() {
    let input=get_input();
    println!("{}", part1_1(&input));
}
{{</ highlight >}}

Now we can use the very popular [Criterion](https://docs.rs/criterion/latest/criterion/) crate to write our `benches/benchmark.rs` 

{{< highlight rust >}}
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use day01::{part1_1, get_input};

pub fn criterion_benchmark(c: &mut Criterion) {
    let input=get_input();
    c.bench_function("part1", |b| b.iter(|| part1_1(black_box(&input))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
{{</ highlight >}}

# The Game Has Changed

With this setup, we are able to run `cargo benchmark` and get cool statistics and measurements of a significant number of executions of our code :sunglasses:.

```
Running benches/benchmark.rs (target/release/deps/benchmark-8bdc3718c6c81796)
part1_1                 time:   [9.5933 µs 9.5953 µs 9.5974 µs]
Found 20 outliers among 100 measurements (20.00%)
  5 (5.00%) low mild
  8 (8.00%) high mild
  7 (7.00%) high severe
```
Not bad at all for our first try! Well, Rust is a fast, compiled language and our input is small, less than 200 lines. Can we do better ? Let's measure a second implementation, will include here only the changed part:

# One More Time

{{< highlight rust >}}
pub fn part1_2(input: &[usize]) -> usize {
    for n in input {
        if input.contains(&(2020 - n)) {
            return n * (2020 - n);
        }
    }
    0
}
{{</ highlight >}}

Turns out our 'smart' implementation has slightly better performance, as **Criterion** is able to detect:

```
Running benches/benchmark.rs (target/release/deps/benchmark-8bdc3718c6c81796)
part1_2                 time:   [8.9454 µs 8.9482 µs 8.9505 µs]
                        change: [-6.9929% -6.8888% -6.7959%] (p = 0.00 < 0.05)
                        Performance has improved.
Found 14 outliers among 100 measurements (14.00%)
  3 (3.00%) low severe
  1 (1.00%) low mild
  3 (3.00%) high mild
  7 (7.00%) high severe
```
# Harder, Better, Faster, Stronger

With the help of a [Set Data Structure](https://doc.rust-lang.org/std/collections/struct.HashSet.html) we can write a better solution:

{{< highlight rust >}}
pub fn part1_3(input: &[usize]) -> usize {
    let mut seen = std::collections::HashSet::new();
    for n in input {
        if seen.contains(&(2020-n)) {
            return n * (2020 - n);
        }
        seen.insert(n);
    }
    0
}
{{</ highlight >}}

We simply keep track of the number already passed, and for each number we check if we already seen its complementary. When yes, we are done!
How much we gain from this trick ?


```
part1_3                 time:   [6.7853 µs 6.7900 µs 6.7947 µs]
                        change: [-0.2564% -0.1246% +0.0135%] (p = 0.08 > 0.05)
Found 5 outliers among 100 measurements (5.00%)
  3 (3.00%) low mild
  1 (1.00%) high mild
  1 (1.00%) high severe
```  

# Doin’ It Right

Our new function is `~30%` faster, and the most important thing is that it runs in *O(n)* time since it iterates over the original data only once. 
I don't want to keep this post too long, also because the main purpose of this exercise isn't abount finding the absolute fastest implementation, but rather to show how to set up a proper benchmark to measure your Rust code. 

As a little spoiler, **Part2** of the daily problem requires us to find `3` numbers which sum up to `2020`. Can you think of a solution ? A fast one ? :santa:

# Around the World

Benchmarking is not only about pure CPU performance, but we should consider also memory usage, I/O, caching, thermal efficiency, parallellism and lots of other topics. Some of them are handly collected in the [Rust Performance Book](https://nnethercote.github.io/perf-book/title-page.html), written by Nicholas Nethercote and others, which is a must read, together with the [Criterion Documentation](https://bheisler.github.io/criterion.rs/book/criterion_rs.html). Happy hacking!








