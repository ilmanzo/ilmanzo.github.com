---
layout: post
title: "background tasks in Ruby e linux"
description: ""
categories: programming
tags: [linux, ruby]
date: 2012-11-05
author: Andrea Manzini
---

A volte negli script Ruby ho bisogno di controllare l'esecuzione di un comando eseguito in modalita' asincrona, ho creato pertanto una classe apposita:

{{< highlight ruby >}}
class BackgroundJob
 
  def initialize(cmd)
    @pid = fork do
     # this code is run in the child process
     # you can do anything here, like changing current directory or reopening STDOUT
     exec cmd
    end
  end
 
  def stop!
    # kill it (other signals than TERM may be used, depending on the program you want
    # to kill. The signal KILL will always work but the process won't be allowed
    # to cleanup anything)
    Process.kill "TERM", @pid
    # you have to wait for its termination, otherwise it will become a zombie process
    # (or you can use Process.detach)
    Process.wait @pid
  end
 
end 

{{</ highlight >}}


come si usa ? Molto semplice:

{{< highlight ruby >}}

    wg = BackgroundJob.new 'wget http://www.google.it'
    sleep 10
    wg.stop!

{{</ highlight >}}

ovviamente non bisogna abusarne ;-)
