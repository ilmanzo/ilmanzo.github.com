---
layout: post
description: "Some basic checks to ensure you bought a good storage for your files"
title: "Testing a cheap MicroSD card quality"
categories: sysadmin
tags: [hardware, storage, testing, scripting, microsd]
author: Andrea Manzini
date: 2024-09-03
---

## 💾 Intro

I just found a *very* cheap SD card on an online store and since I know that [there are some fake around](https://iboysoft.com/sd-card-recovery/fake-sd-card.html), I wanted to quickly test if its size and speed respect the specs.

Edit: after first publish, a kind reader noticed me that [The F3 tools](https://fight-flash-fraud.readthedocs.io/en/latest/introduction.html) are a perfect fit for the same task and that's right; if you want to follow a manual path and learn something in the journey, continue reading... 

## ✍️ The write test

What are we going to check ? For example I want to fill the entire space with many files (big and/or small) and see if I'm able to re-read them.
Since my card size should be 32GB, I can manage to create at least 30 x 1GB files: 

```
mmcblk0     179:0    0  30.8G  0 disk 
└─mmcblk0p1 179:1    0  30.8G  0 part /run/media/andrea/9016-4EF8
```

(note: mmcblk0 is the device name for the SD card)

let's make a script that creates many files, checksum them and move to the microsd:

```bash
#!/bin/sh
cd /tmp
DESTDIR=/run/media/andrea/9016-4EF8 # the mount path of the microsd card
for n in $(seq -w 30); do 
  dd if=/dev/random of=bigfile$n bs=1M count=1024 status=none
  sha256sum bigfile$n | tee -a checksums.txt
  time mv bigfile$n $DESTDIR
done
sync
```

running the script, we start collecting the output:

```
3cbcc7583c68115996f22745b37c02bd13b9df8d164c212883af77924bcbf113  bigfile01

real    0m42,415s
user    0m0,000s
sys     0m1,984s
005ac6aab0d0c4f08c9813fbe8f6baa6d2c4f8be41646344fbabcb9af313dc89  bigfile02

real    0m41,676s
user    0m0,004s
sys     0m1,790s
8cf990ba2e3df87db55adca975f6cc24a89e915a72dc7be2bf7be6ad0cedde47  bigfile03

real    0m41,541s
user    0m0,004s
sys     0m1,631s
2f7653161e4c2679116042598fe0298fae8fe02ada9bb72526037bcd16247fee  bigfile04

real    0m42,309s
user    0m0,000s
sys     0m1,246s
5e350cf51aba24490b4fb31bef4766ad165790b8fe510b8467668a598ef80620  bigfile05

real    0m40,725s
user    0m0,000s
sys     0m1,661s
a035ddd2161119249e5841c45036dcf5e29c8c19c16506ebf964e03baab1e7a9  bigfile06

real    0m41,860s
user    0m0,000s
sys     0m1,190s
b147d9de194fbca4499a9af77d23fe7aaedd55bacc3c9f0edd5c211f96653895  bigfile07

real    0m40,929s
user    0m0,000s
sys     0m1,744s
74e0b502a6ee6f020bb5c9acded9ace276ea28d15a6ff11e7101d5017c0dcfdc  bigfile08

real    0m41,350s
user    0m0,000s
sys     0m1,614s

[and so on]

```

Note that thanks to the [`tee` command](https://www.geeksforgeeks.org/tee-command-linux-example/), the sha256sum of each file is also conveniently stored in a `checksums.txt`, for a later use.

Not a truly *scientific* measure but we can see that writing ~1GB to this card takes somewhat more than 40 seconds, which means **transfer speed is a little under ~25 MB/s** (which qualifies for "High Speed"). Since this specific card was advertised as UHS-1, we can say it passes the write speed test.

If we want to "stress" the media a bit, we can also repeat the script many times until we think it's sufficient.
Now we can eject the card, waiting for the last writes to finalize; then we can easily check if the content is the same when read back.

## 👀 The read test 

The `sha256sum` program has a special and convenient `-c` option that accepts a file containing the pairs of checksum and filename, which is what we produced in the previous step:

```bash
DESTDIR=/run/media/andrea/9016-4EF8 # the mount path of the microsd card
cd $DESTDIR ; time sha256sum -c /tmp/checksums.txt
bigfile01: OK
bigfile02: OK
bigfile03: OK
bigfile04: OK
bigfile05: OK
bigfile06: OK
[...]
bigfile22: OK
bigfile23: OK
bigfile24: OK
bigfile25: FAILED
bigfile26: OK
bigfile27: OK
bigfile28: OK
bigfile29: OK
bigfile30: OK
sha256sum: WARNING: 1 computed checksum did NOT match
sha256sum -c /tmp/checksums.txt  154,26s user 23,13s system 49% cpu 5:55,02 total

```

The measured read speed is somewhat around 192 MB/s , altough filesystem cache plays a big role here. 

## ⚠️ Conclusion

The interesting part of the final test is that some files failed the checksum, this could be sufficient to consider this card not reliable for a production usage.
In short: be aware of cheap microsd card you buy, and be sure to always keep a testing mindset! ✅

