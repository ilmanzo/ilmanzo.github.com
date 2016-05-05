---
layout: post
title: "monit helper for quota monitoring in go"
description: "a small program to parse quota information and report via monit"
category: sysadmin
tags: [linux, quota, golang, sysadmin, monit]
---
{% include JB/setup %}

I want to keep under control a system where each user has an amount of filesystem quota reserved; in particular I would like to get notified if and when a user exceeds some treshold. Since I already have [Monit](https://mmonit.com/monit/) in place in the server, I took the chance to write a small [Go](https://golang.org/) utility in order to retrieve the quota percentage.

{% highlight go linenos %}
// quotachecker.go
package main

import (
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

func main() {
    //a fake implementation, just for testing purpose
	//cmd := exec.Command("/bin/sh", "-c", "cat fakequota.txt")
	cmd := exec.Command("/usr/bin/repquota", "-a")
	stdout, err := cmd.Output()
	if err != nil {
		panic(err.Error())
	}
	re, err := regexp.Compile("^[[:alnum:]]+\\s+--\\s+\\d+\\s+\\d+")
	if err != nil {
		panic(err.Error())
	}
	percent_max := 0
	result := strings.Split(string(stdout), "\n")
	for _, line := range result {
		match := re.MatchString(line)
		if !match {
			continue
		}
		fields := strings.Fields(line)
		spaceused, err := strconv.ParseInt(fields[2], 10, 64)
		if err != nil {
			panic(err.Error())
		}
		spacetotal, err := strconv.ParseInt(fields[4], 10, 64)
		if err != nil {
			panic(err.Error())
		}
		if spacetotal == 0 {
			continue
		}
		//calculate max percent used
		percent := int(100 * spaceused / spacetotal)
		if percent > percent_max {
			percent_max = int(percent)
		}
	}
	os.Exit(percent_max)
}
{% endhighlight %}

This is also an example on how to run external programs in [Go](https://golang.org/) and filter the output using regular expressions.

Once compiled with **go build** , you can use this program (without any extra dependencies) in a [Monit](https://mmonit.com/monit/) config file, like this:

{% highlight bash %}
check program quota with path /usr/local/bin/quotachecker
       if status > 90 for 5 cycles then alert
{% endhighlight %}

and you will be alerted if any user exceed 90% of his quota on disk.

