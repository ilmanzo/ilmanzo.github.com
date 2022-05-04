---
layout: post
title: "integration between Python and Rust - Part 1"
description: "some experiments with language FFI"
categories: programming
tags: [python, Rust, linux, programming, learning]
author: Andrea Manzini
date: 2021-08-18
---


Let's get our feet wet; in this first part I'll write about a very simple way to interface Rust and Python.
First of all let's build a Rust dynamic library with some basic functions.

{{<highlight rust >}}
// this file is: src/lib.rs

#[no_mangle]
pub extern "C" fn hello() {
    println!("Hello from the library!");
}

#[no_mangle]
pub extern "C" fn sum(a: i32, b: i32) -> i32 {
    a + b
}
{{</ highlight >}}

your ```Cargo.toml``` should look like this:

{{<highlight toml >}}
[package]
name = "pyrust"
version = "0.1.0"
edition = "2018"

[dependencies]

[lib]
crate-type = ["cdylib"]
{{</ highlight >}}

compile the library with ```cargo build```

now we need a trivial python program to test our library:

{{<highlight python >}}
import ctypes
lib=ctypes.PyDLL("target/debug/libpyrust.so")
lib.hello()
c=lib.sum(3,4)
print(c)
{{</ highlight >}}

running it, we get the expected result:

{{< highlight bash >}}
$ python3 test_lib.py 
Hello from the library!
7
{{</ highlight >}}

since we exported our functions from Rust as plain C, and we don't make any fancy allocation or manipulation of Python objects, it's pretty standard to use the library as it was written in C. In the next post we'll explore more advanced options...



