---
layout: post
title: "get update info about packages"
description: "a simple wrapper to get last update date on a package"
categories: automation
tags: [linux, bash, programming, testing, automation, python]
author: Andrea Manzini
date: 2022-11-24
---

being lazy, I made a small utility to check last pkgs update date on [Open Build Service](https://build.opensuse.org/). 

You can find the project repository [on my github](https://github.com/ilmanzo/package_last_update), but it's so simple I can paste also here.

The [usage](https://github.com/ilmanzo/package_last_update/blob/master/README.md) is pretty simple: just run the command giving it a package name, and then it will tell you when it was last updated. With this information, you can decide/check if the package needs some work on!



<!--more-->

{{< highlight python >}}
#!/usr/bin/python3
import subprocess
import argparse

APIURL = "https://api.opensuse.org"
MAINPROJECT = "openSUSE:Factory"
###

OSC_CMD = ['osc', '--apiurl', APIURL]

def exec_process(cmdline):
    return subprocess.Popen(cmdline, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding='utf8')

def get_last_changes(package):
    try:
        proc = exec_process(
            OSC_CMD+["ls", "-l", f"{MAINPROJECT}/{package}"])
        for line in proc.stdout.readlines():
            if f"{package}.changes" not in line:
                continue
            return line.split()[3:6]
    except:
        return None

def main():
    parser = argparse.ArgumentParser(
        prog='last update',
        description='tells you when a package was last updated',
    )
    parser.add_argument(
        'package', help='the package name to check (ex bash, vim ...)')
    args = parser.parse_args()
    changes = get_last_changes(args.package)
    if changes:
        print(args.package, "was last updated on", MAINPROJECT,
              ' '.join(get_last_changes(args.package)))
    else:
        print("Error in getting information. Does this package exist?")

main()
{{</ highlight >}}


Have fun!

