---
layout: post
description: "Understand how much power you are using"
title: "Measure your programs power consumption"
categories: linux
tags: [linux, tutorial, system, hardware, power, energy, optimization]
author: Andrea Manzini
date: 2024-06-30
---

## 🌡️ Intro

For those running a datacenter, or just a simple homelab server, the arrival of summer heat means an increase in air conditioning use. On this post I asked myself how a Linux engineer can measure how much energy is the system consuming so we can start to reason about workload optimization for better power consumption patterns.

## 🔋 Idle power drain

As a starting point, let's measure how much power my PC is consuming when idle, doing absolutely nothing; or better: nothing useful for computation or service but just running usual, default operating system tasks.

There are many way to do it; the most reliable probably is using a proper external power meter device like this one.

![powermeter](https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/SWR_%26_power_meter_front_view.jpg/640px-SWR_%26_power_meter_front_view.jpg) 

[image from Wikimedia Commons](https://commons.wikimedia.org/wiki/File:SWR_%26_power_meter_front_view.jpg)

Since I'm a software engineers, don't want to mess much with cables; and on many occasion it's not practical to disconnect the servers just to do some power measure. As a pure software solution, some rough measurements can be obtained with the help of [powerstat](https://github.com/ColinIanKing/powerstat) utility, which uses many methods (like battery stats or the *Intel RAPL interface*, which stands for Running Average Power Limit) to estimate the power consumption of a running computer.

```
# powerstat -zR
[...]

-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Average   0.1   0.0   0.2  99.4   0.2  1.1  916.3  479.6  0.2  0.0  0.4  29.98 
 GeoMean   0.1   0.0   0.2  99.4   0.2  1.1  882.5  463.9  0.0  0.0  0.0  29.89 
  StdDev   0.1   0.0   0.1   0.3   0.2  0.3  408.7  169.7  0.7  0.0  2.1   2.64 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Minimum   0.1   0.0   0.1  96.9   0.1  1.0  730.0  377.0  0.0  0.0  0.0  28.74 
 Maximum   0.8   0.0   0.6  99.6   1.6  2.0 3987.0 1589.0  5.0  0.0 16.0  44.31 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
Summary:
CPU:  29.98 Watts on average with standard deviation 2.64  
Note: power read from RAPL domains: uncore, pkg-0, core, psys.
These readings do not cover all the hardware in this device.
```

## ⚡ Put it to work

So my computer, a ThinkPad P15 Gen 2i, uses ~30 Watts (or ~30 Joule / sec) to do nothing, which if you ask me, I'd rate pretty bad. Let's make some experiments with different workloads, like what every computer should be good at: calculating prime numbers!

The experiment idea is to see how much energy it costs to get the first million prime numbers; accordingly to [prime numbers wiki](https://prime-numbers.fandom.com/) the 1,000,000th prime number should be 15,485,863.

I started with a rather dumb Python program that's on purpose absolutely not optimized:

```python
from math import sqrt

def isPrime(n):
  for j in range(3,int(sqrt(n)+1),2):
    if n % j == 0:
      return False
  return True

n,i = 2,3
while n < 1_000_000:
    i += 2
    if isPrime(i):
        n += 1
print("Prime number =", i)
```

And run it with `powerstat` measurement in background:


```
# (powerstat -zR 1 60 &) ; /usr/bin/time python3 /tmp/prime.py
```

```
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Average   6.3   0.0   0.2  93.4   0.1  2.0 1003.4 1168.7  0.1  0.0  0.5  56.65 
 GeoMean   6.3   0.0   0.1  93.4   0.0  2.0  872.7  964.3  0.0  0.0  0.0  56.26 
  StdDev   0.1   0.0   0.1   0.1   0.0  0.1  750.7 1184.1  0.4  0.1  1.7   7.55 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Minimum   6.3   0.0   0.1  92.7   0.0  2.0  561.0  697.0  0.0  0.0  0.0  53.39 
 Maximum   7.1   0.0   0.4  93.6   0.1  3.0 4135.0 6576.0  2.0  1.0 10.0  90.93 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
Summary:
CPU:  56.65 Watts on average with standard deviation 7.55  
Note: power read from RAPL domains: uncore, pkg-0, core, psys.
These readings do not cover all the hardware in this device.

Prime = 15485863
61.68user 0.00system 1:01.71elapsed 99%CPU (0avgtext+0avgdata 8064maxresident)k
0inputs+0outputs (0major+879minor)pagefaults 0swaps
```

Notice how variable the numbers are over time! So, when doing calculations, my pc almost doubles the power consumption. I keep it safe and say that ~27W is the extra power required to run my poor Python prime number calculator.

Since the program runs for ~61.5 seconds, running it requires ~3490 Joule of energy or 0.0009694444 kWh; of course this is only about the CPU and does not include graphic card, disk subsystem, display, network and so on.

## 📏 An alternative measure

Another way to read the RAPL metrics is by using the powerful [perf](https://perf.wiki.kernel.org/index.php/Main_Page) utility. This tool can read many probes exposed from the kernel so maybe in the future we should dedicate it a whole post.

```bash 
# perf list --details power*

List of pre-defined events (to be used in -e or -M):

  power/energy-cores/                                [Kernel PMU event]
  power/energy-pkg/                                  [Kernel PMU event]
  power/energy-psys/                                 [Kernel PMU event]

[output omitted]
```

The `power/energy-cores/` perf counter is part of the Intel RAPL interfaced, based on an CPU MSR register called `MSR_PP0_ENERGY_STATUS`.
The other two are power measurements relative to the package (cores and uncore components) and the entire System on Chip; the latter one is available from Skylake architecture.

Lets' run our Python program asking perf to collect the metrics during the execution:

```bash
# perf stat -ae power/energy-cores/,power/energy-pkg/,power/energy-psys/ python3 /tmp/prime.py
Prime = 15485863

 Performance counter stats for 'system wide':

            695.00 Joules power/energy-cores/                                                   
            930.12 Joules power/energy-pkg/                                                     
           1855.48 Joules power/energy-psys/                                                    

      61.362063830 seconds time elapsed
```
## 🚀 We can do better

for a performance comparison, let's check the same algorithm written in Rust:

```Rust
fn is_prime(n: u64) -> bool {
    let sqrt_n = (n as f64).sqrt() as u64;
    for j in (3..=sqrt_n).step_by(2) {
        if n % j == 0 {
            return false;
        }
    }
    true
}

fn main() {
    let mut n = 2;
    let mut i = 3;

    while n < 1_000_000 {
        i += 2;
        if is_prime(i) {
            n += 1;
        }
    }
    println!("Prime = {}", i);
}
```

Note: we simply translated the Python code, without any attention to optimization.

```bash
$ cargo build --release
   Compiling prime1m v0.1.0 (/home/andrea/projects/prove/prime1m)
    Finished `release` profile [optimized] target(s) in 0.12s

# perf stat -ae power/energy-cores/,power/energy-pkg/,power/energy-psys/ ./target/release/prime1m
Prime = 15485863

 Performance counter stats for 'system wide':

             24.46 Joules power/energy-cores/                                                   
             36.17 Joules power/energy-pkg/                                                     
             82.12 Joules power/energy-psys/                                                    

       2.987509303 seconds time elapsed
```

As expected, to give the same output, the compiled program is ~20x faster, and uses less resources and energy. Sounds interesting!

## 📚 Further insights

RAPL (Running Average Power Limit) is a hardware feature introduced by Intel to facilitate power management; the RAPL interface is discussed in Section 14.9 of the Intel Manual Volume 3. 
If you want to know more about this framework, I can recommend also [this research article](https://dl.acm.org/doi/10.1145/3177754).

The `perf` tool can do much more than reading power metrics from the kernel. If you want to see some examples, check out the ubiquitous [Brendan Gregg](https://www.brendangregg.com/perf.html) website.

Enjoy and happy green computing!