---
layout: post
title: "integration between Python and Rust - Part 2"
description: "some experiments with language FFI"
categories: programming
tags: [python, Rust, linux, programming, learning]
author: Andrea Manzini
date: 2022-01-07
---

In this post we are going to write a new module for python: a very simple function exported from Rust that we can consume in the Python interpreter. We'll leverage the [PyO3](https://github.com/PyO3) Rust bindings for the Python interpreter. 

Let's start with a new Cargo project:

{{< highlight bash >}}
$ cargo init --lib demo_rust_lib
{{</ highlight >}}

and insert the required settings in ```Cargo.toml```:

{{< highlight toml >}}
[package]
name = "rusty"
version = "0.1.0"
edition = "2021"

[lib]
name="rusty"
crate-type = ["cdylib"]


[dependencies.pyo3]
version = "*"

[features]
extension-module = ["pyo3/extension-module"]
default = ["extension-module"]
{{</ highlight >}}

now it's a matter to write our library; luckily the PyO3 library exposes a lot of useful types for python interop; the only thing we need to add is an extra fn named as our module that "exports" the functions we want to make available in the Python layer:



{{<highlight rust >}}
// this file is: src/lib.rs
use pyo3::prelude::*;

#[allow(dead_code)]

#[pymodule]
 fn librusty(_py: Python, m: &PyModule) -> PyResult<()> {
     m.add_wrapped(wrap_pyfunction!(list_prod))?;
     Ok(())
}

/// calc the product of N numbers in a list.
#[pyfunction]
fn list_prod(a: Vec<isize>) -> PyResult<isize> {
    let mut prod: isize = 1;
    for i in a {
        prod *= i;
    }
    Ok(prod)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_list_product() {
        let input=vec![1,2,3,4];
        let result=list_prod(input).unwrap_or(0);
        assert_eq!(result, 24);
    }
}
{{</ highlight >}}

now compile the library with ```cargo build``` and also unit test are working, so you can run them with ```cargo test --no-default-features```

now we need a trivial python program to test our library:

{{<highlight python >}}
import sys,os 

# for development we include the rust build path to the path
# that python looks for modules
for p in ("release","debug"):
    sys.path.append(os.path.join("target",p))

# now this import can be resolved
from librusty import list_prod

result=list_prod([10,3,6])

print(result)
{{</ highlight >}}

The initial part requires a bit of setup because Python must be aware of Rust's target folder to load the external module. For development is fine, but in the future we can skip this and publish the module as a real python package, installable from **pip** using the [maturin](https://github.com/PyO3/maturin) tool from PyO3.

Running the sample program, we get the expected result:

{{< highlight bash >}}
$ python3 use_rust_lib.py 
180
{{</ highlight >}}

we are starting to make interesting interactions between Python and Rust. The main purpose of this kind of project can be performance improvements, so next time we will do some benchmarks on the same function implemented in both and see the results.

All of the source code for this post is available on [github](https://github.com/ilmanzo/python-modules-in-rust)


