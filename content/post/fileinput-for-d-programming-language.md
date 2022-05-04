---
layout: post
title: "a 'pythonic' fileinput module for the D programming language"
description: "an implementation of a custom iterator similar to Python's fileinput"
categories: programming
tags: [python, D, dlang, programming, learning]
author: Andrea Manzini
date: 2021-01-25
---


When I write small command line utilities in [Python](https://www.python.org/), I often take advantage of [the fileinput module](https://docs.python.org/3/library/fileinput.html) that makes working with text files very convenient: the library permits to write quickly and easily a loop over standard input or a list of files, something like ```perl -a``` or awk line processing.

Then the size of input data grew, and also for a language comparison, I wanted to port my utility in the [D programming language](https://dlang.org/), but I cannot find an equivalent module, so I decided to write one myself.

The usage is pretty similar to Python:

{{<highlight dlang >}}
import fileinput;
import std.stdio;

void main(in string[] args)
{
    foreach (line; fileinput.input(args))
    {
        writeln(line); // do something with line
    }
    return;
}

{{</ highlight >}}

Once compiled, this will lead to an executable that can accept any number of text file as input, or read from stdin and seamlessly iterate on all of the lines contained in every file.

Thanks to the [range interface](https://tour.dlang.org/tour/en/basics/ranges); every struct / class implementing these methods can be used in a foreach statement.

{{<highlight dlang >}}
interface InputRange(E)
{
        bool empty();
        E front();
        void popFront();
}
{{</ highlight >}}

You can find the full implementation [on github](https://github.com/ilmanzo/fileinput-d/blob/main/source/fileinput.d)