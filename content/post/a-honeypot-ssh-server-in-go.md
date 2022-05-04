---
layout: post
title: "a honeypot ssh server in Go"
description: "a fake ssh server that works as a honeypot, written in Go"
categories: programming
tags: [go, golang, programming, ssh, linux, hacking]
author: Andrea Manzini
date: 2018-06-26
---


## honey-ssh-pot

Curious about who and how attempts ssh login to your home server ? Me too... So I wrote a very simple ssh honeypot, just to collect interesting info about the kind guys who knocks my door :)

warning: this is safe, but don't run the service (well, ANY service) as root user. Even better if you can run it as a dedicate unprivileged user.

This program is only for didactic use and not intended for deployment in a production network environment.

If you want to have it exposed on the public internet, you must map port 22 of your wan router to the internal server port ( 2222 by default)... Do it at your risk!


{{< highlight go >}}

package main

import (
        "github.com/gliderlabs/ssh" 
        "io"
        "log"
        "log/syslog"
        "os"
)

// this is the function called when ssh client requests authentication
// here we log attacker credentials on purpose
func authHandler(ctx ssh.Context, password string) bool {
        log.Printf("User: %s connecting from %s with password: %s\n", 
          ctx.User(), ctx.RemoteAddr(), password)
        return true
}

// dear guest, your ssh session will be very short...
// to free up resources we only send a message and quit
func sessionHandler(s ssh.Session) {
        io.WriteString(s, "Welcome!\n")
}

func main() {

        // Configure logger to write to the syslog
        logwriter, e := syslog.New(syslog.LOG_INFO, os.Args[0])
        if e == nil {
                log.SetOutput(logwriter)
        }

        s := &ssh.Server{
                Addr:            ":2222",
                Handler:         sessionHandler,
                PasswordHandler: authHandler,
        }
        log.Println("starting ssh server on port 2222...")
        log.Fatal(s.ListenAndServe())
}

{{</ highlight >}}

{{< highlight bash >}}

$ git clone https://github.com/ilmanzo/honey-ssh-pot.git
$ go get github.com/gliderlabs/ssh
$ go build -ldflags="-s -w" # makes a smaller binary
$ ./honey-ssh-pot 

{{</ highlight >}}

now get some popcorn and watch on your syslog :)


{{< highlight bash >}}
$ tail -f /var/log/messages
./honey-ssh-pot[24125]: 2018/06/26 21:50:09 starting ssh server on port 2222...
./honey-ssh-pot[24125]: 2018/06/26 21:50:40 User: evilhacker connecting from 127.0.0.1:51182 with password: secretpassword
{{</ highlight >}}


credits to [gliderlabs](https://github.com/gliderlabs) for the awesome ssh wrapper package. Thank you guys !

