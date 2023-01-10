---
layout: post
title: "compare package version across distros"
description: "a tool to check if an openSUSE package version is up to date against other distros"
categories: automation
tags: [linux, bash, programming, testing, automation, python]
author: Andrea Manzini
date: 2023-01-09
---

TLDR: This script now answers the question "Do some of my openSUSE packages have newer versions in other distros?"


As a following on [previous post](https://ilmanzo.github.io/post/check-last-update-on-packages/), I added an useful feature in order to have more information about a package.
Since I maintain some openSUSE packages, I want to be informed if they gets outdated and if other packagers have released newer versions.

<!--more-->

You can still find the project repository [on my github](https://github.com/ilmanzo/package_last_update), but we can comment some parts here. 

Other than collecting the package version from Open Build Service, we need to find out how the same packages in other distro are doing. We could scrape major distros public repositories but turns out there's already an excellent service named [repology](https://repology.org/) that exposes some API that can easily be queried:

{{< highlight python >}}

REPOLOGY_APIURL = 'https://repology.org/api/v1/project/'

# return a package info when its version is different than the reference one
def get_repology_version(package, refversion):
    try:
        response = requests.get(f"{REPOLOGY_APIURL}/{package}")
        return [r for r in response.json() if r['status'] == 'newest' and r['version'] != refversion]
    except:
        return None

{{</ highlight >}}

A companion shell script gets the info for all the packages I'm in charge of; I run it on every morning login so I won't risk to forget something.

{{< highlight bash >}}

#!/bin/sh
for p in $(osc -A https://api.opensuse.org my packages | cut -d '/' -f 2) ; do ./last_update $p ; done

{{</ highlight >}}

which outputs:

    - rang last version on openSUSE:Factory is 3.2 changed on Dec 17 2022
      Other 7 repos may have newer versions, consider updating!
    - pgn-extract last version on openSUSE:Factory is 22.11 changed on Dec 23 2022
    - flacon last version on openSUSE:Factory is 9.5.1 changed on Dec 26 2022
    - goodvibes last version on openSUSE:Factory is 0.7.5 changed on Oct 16 2022
    - openconnect last version on openSUSE:Factory is 9.01 changed on Dec 15 2022
    - oidentd last version on openSUSE:Factory is 3.0.0 changed on Oct 21 2022
    - pgbackrest last version on openSUSE:Factory is 2.43 changed on Dec 07 2022


There are of course tons of possible improvements. For example use directly [osc-tiny](https://github.com/crazyscientist/osc-tiny) by [Andreas Hasenkopf](https://github.com/crazyscientist) and improve the OBS version detection. At this stage for example it does not yet support rpm macros. Pull requests are welcome! 

Have fun ;) 

