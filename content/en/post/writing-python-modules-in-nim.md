---
layout: post
title: "Writing Python modules in Nim"
description: "how to write a Python module using the Nim programming language"
categories: programming
tags: [python, nim, nim language, programming, learning]
author: Andrea Manzini
date: 2020-12-05
---

[Nim](https://nim-lang.org/) is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula. It's **Efficient, expressive, elegant** and definitely worth to check.


While I was playing with it, I stumbled upon [an interesting module](https://github.com/yglukhov/nimpy) that allows almost seamless interoperability betweeen Nim and Python; so I'm building a small proof of concept on [this github project](https://github.com/ilmanzo/python-modules-with-nim). 

first of all the Nim code:
{{< highlight nim >}}
# file: demo.nim - file name should match the module name you're going to import from python
import nimpy

import unicode

proc greet(name: string): string {.exportpy.} =
  return "Hello, " & name & "!"


proc count(names: seq[string]): int {.exportpy.} =
  return names.len

proc lowercase(names: seq[string]): seq[string] {.exportpy.} =
  for n in names:
    result.add tolower(n)
{{</ highlight >}}

In the github project there is a complete [build file](https://github.com/ilmanzo/python-modules-with-nim/blob/master/demo.nimble), but to make it short, you can compile the module with a single command:

{{< highlight bash >}}
#for windows:
nim c --threads:on --app:lib --out: demo.pyd demo
#for linux:
nim c --threads:on --app:lib --out: demo.so demo
{{</ highlight >}}

now we can import the module from python and use its functions:

{{<highlight python >}}
# file: usage.py
import demo
#
assert demo.greet("world") == "Hello, world!"
assert demo.greet(name="world") == "Hello, world!"
#
fruits=["banana","apple","orange"]
assert demo.count(fruits) == 3
#
upletters=["AA","BB","CC"]
letters=demo.lowercase(upletters)
assert "".join(letters) =="aabbcc"
#
print("all test sucessful")
{{</ highlight >}}
