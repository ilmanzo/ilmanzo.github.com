---
layout: post
title: "convert a binary file to ascii using hexdump"
description: "convert a binary file to ascii using hexdump"
categories: sysadmin
tags: [linux, sysadmin, hexdump, binary, ascii]
author: Andrea Manzini
date: 2016-10-20
---


I have a binary file with data stored as two-byte big-endian 16-bit words. We need to extract the values in the file and print them in decimal ASCII format, so to obtain numbers in the 0-655535 range.

let's create the sample file:

{{< highlight bash >}}
$ echo -en "\x01\x02\x03\x04\x05\x06\x07\x08" > file.bin
{{</ highlight >}}

and show its content in binary form:

{{< highlight bash >}}
$ hexdump -C file.bin
00000000  01 02 03 04 05 06 07 08                           |........|
00000008
{{</ highlight >}}

to get the desired output we can use the powerful, but little documented *format string* option of hexdump:

{{< highlight bash >}}
$ hexdump -e '/2 "%d\n"' file.bin
513
1027
1541
2055
{{</ highlight >}}

also see more on [https://www.suse.com/communities/blog/making-sense-hexdump/](https://www.suse.com/communities/blog/making-sense-hexdump/)
