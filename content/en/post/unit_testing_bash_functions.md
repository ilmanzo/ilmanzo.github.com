---
layout: post
title: "Using containers for unit testing of bash functions"
description: "How to create an isolate environment to safely test your bash scripts"
categories: programming
tags: [programming, bash, testing, test, container, podman, 'unit testing']
author: Andrea Manzini
date: 2023-08-17
---

## Intro

Unit testing of Bash functions involves the process of systematically verifying the correctness and reliability of individual functions within a Bash script. While Bash is primarily used for scripting and automation, it's important to ensure that the functions within your scripts work as expected, especially as scripts become more complex. Unit testing in Bash can help catch bugs and prevent unexpected behavior.

## Fixing bugs

Working on a bugfix for an internal shell script, I wanted to add some unit tests to ensure correctness. After a quick search, I found this [single-file "framework"](https://github.com/rafritts/bunit) (thanks, Ryan) that provides *xUnit*-style assertions. So we can use it as a starting point.

The main problem with the script under test is that it contains functions that directly manipulates the host filesystem, so it can be hard to extract and *mock* those interactions for proper testing.

So I decided to use a simple container to run the script in an isolated environment. While we are at, no need for daemons, just use rootless podman. This is the main script, the only to be executed and which runs all the testsuites:

{{< highlight bash >}}
#!/bin/bash

# This script will run unit test for functions in file "mylib".
# the tests are run in a container to ensure isolation from host system

if [ "$EUID" -eq 0 ]
  then echo "Please don't run this script as root"
  exit
fi
# optionally, you can use different distro images here
podman run -v ..:/mnt registry.opensuse.org/opensuse/leap:latest bash /mnt/unit_tests/test_mylib.ut
{{</ highlight >}}

## Run your test without damaging your system

Inside the `test_mylib.ut` itself, which is not executable, I added another safety check, so the user is aware that test script is safe to be run only inside a container:

{{< highlight bash >}}
#!/bin/bash

source "/mnt/unit_tests/bunit.shl"
source "/mnt/mylib.sh"

function testSetup() {
  [...]
}

function test_single() {
    [...]
    assertEquals 0 $?
}

function test_duplicate() {
    [...]
    local output=$( ... )
    assertNull "$output"
}

## safety check
if [ "$container" != "podman" ]; then
  echo "ERROR: this is script is not intended to be run directly."
  echo "Don't run this script standalone/outside a container, it will break your system"
  exit 0
else
  echo "Starting test..."
  runUnitTests
fi
{{</ highlight >}}

## Outro

In conclusion, unit testing of Bash functions is an essential practice to ensure the reliability, correctness, and maintainability of your scripts. By creating comprehensive test suites and employing testing frameworks, developers can catch bugs early, improve code quality, and confidently make changes to their scripts. While testing Bash scripts might require additional considerations due to their interactions with external resources, the benefits of unit testing far outweigh the challenges, leading to more robust and predictable scripting solutions.