---
layout: post
title: "web components with Nim and Karax"
description: "how to create a simple web component in a Karax web application"
categories: programming
tags: [nim, nim_language, web, programming]
author: Andrea Manzini
date: 2022-07-07
---

Inspired by a [tweet](https://twitter.com/pietroppeter/status/1542484628531019776?s=20&t=GZdX9XAmh1pGTka2hj8OVQ) from a fellow developer, I decided to take a look at [Karax](https://github.com/karaxnim/karax), a nifty framework for developing single page applications in Nim.


After following the basic tutorials and examples, I searched for something more complex and found very sparse documentation, so I'll write my findings here.


As usual, the complete source code is [on my github repo](https://github.com/ilmanzo/karax_clock), where you can find also a working [live demo](https://ilmanzo.github.io/karax_clock/).


In this example I wanted to experiment with the component pattern, and create a stateful module that can be reused. So I modeled a nim *clock* object, here the source:

{{< highlight nim >}}
# source for the Clock component
import karax/[karax, karaxdsl, vdom]
import std/times
import std/dom
import sugar

type
  KClock* = ref object of VComponent
    currentTime: DateTime
    offset: TimeInterval
    timer: TimeOut
    prefix: string

# return a VNode with the html rendered for the component
proc render(c: VComponent): VNode =
  let self = KClock(c)
  buildHtml(tdiv):
    let value = format(self.currentTime+self.offset, "HH:mm:ss")
    p:
      text "Local Time " & self.prefix & " => " & value

# update the clock value and re-triggers a timer
proc update(self: KClock) =
  self.currentTime = now()
  self.timer = setTimeout( () => self.update, 100)
  markDirty(self) # need to be re-rendered
  redraw()

# create, initialize and return a new Clock object
proc new*(T: type KClock, tzoffset = 0): KClock =
  let self = newComponent(KClock, render)
  self.currentTime = now()
  self.offset = initTimeInterval(hours = tzoffset)
  self.timer = setTimeout(() => self.update, 100)
  self.prefix = if tzoffset >= 0: "+" else: ""
  self.prefix.add $tzoffset
  return self
{{</ highlight >}}

this lives in a separate file and can be imported from the main page. 

Some attention point goes in the constructor, that requires special ```newComponent``` call, and the ```update()``` function that contains a Timeout callback in order to re-render itself after some time.

let's use the component in the main page, and sprinkle some interactivity just for fun:

{{< highlight nim >}}
import karax / [kbase, vdom, kdom, karax, karaxdsl, jstrutils]
import kclock

var
  clocks: seq[KClock] # keep a list of clocks
  offset: kstring     # value entered in the input box

proc render(): VNode =
  buildHtml(tdiv):
    h2:
      label(`for` = "offset"):
        text "Please enter Timezone offset (-12 .. +12)"
      input(type = "number", id = "offset"):
        proc oninput(ev: Event; n: VNode) =
          offset = n.value
    button:
      text "Add a new Clock"
      proc onclick(ev: Event; n: VNode) =
        let tzofs = parseInt(offset)
        if tzofs >= -12 and tzofs <= 12:
          clocks.add(KClock.new(tzofs))
    button:
      text "Remove last Clock"
      proc onclick(ev: Event; n: VNode) =
        discard clocks.pop()
    for clock in clocks:
      h1:
        clock

setRenderer render
{{</ highlight >}}

for Nim lovers, Karax looks promising, and programming web pages without writing a single Javascript line sounds very interesting; but currently it needs some polish, more documentation and a larger user base. So try and contribute to the development community!

