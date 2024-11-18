---
layout: post
description: "Personal recap of GoLab 2024 conference"
title: "Wrapping up GoLab 2024"
categories: conference
tags: [go, golang, programming, developers, SUSE, conference]
author: Andrea Manzini
date: 2024-11-15
---

## Intro

Since 2015, GoLab is one of the oldest and most renowned conferences about the [Go Programming Language](https://go.dev/) ecosystem in the world, attracting a large audience of Gophers from all over the globe. 

{{< figure src="/img/golab_2024/IMG_20241113_074003.jpg" height=300 link="/img/golab_2024/IMG_20241113_074003.jpg" caption="My bad, I forgot to take a picture of the t-shirt 🤷" >}} 

In recent years, the [organizers](https://www.develer.com/en/) hosted some of the biggest names in the industry who have shared their insights and experiences with our attendees.

As a welcoming first impression, the venue was a beautiful hotel in the charming city of Florence ⚜️, I just love this place and can't add much more.

{{< figure src="/img/golab_2024/IMG_20241112_092235.jpg" height=300 target="_blank" link="/img/golab_2024/IMG_20241112_092235.jpg" >}} 

Notable choice, on 2024 GoLab was on the days after RustLab, while on the previous year the two events overlapped on the same location. A wise choice to avoid confusion and risk to lose your preferred talk!

Big kudos to the [organizers](https://www.develer.com/en/) as they choose to deliver a [sustainable conference](https://golab.io/golab-for-the-planet): plant a tree for each speaker, eliminate plastic, support sustainable travel and completely vegetarian lunch / snacks offering.

The three days of the [schedule](https://golab.io/schedule) were packed, with the first one reserved for in-depth workshops. More than 400 people from all over the planet attended the conference, 30 selected speakers among world best companies (SUSE included).

## Some Personal Highlights

{{< figure src="/img/golab_2024/IMG_20241112_100342.jpg" height=300 target="_blank" link="/img/golab_2024/IMG_20241112_100342.jpg" caption="a crowded welcome" >}} 

As I was able to attend approximately half of the talks, I feel like I missed some very good ones; here you can have a quick recap of my favorites:

### Day one 

- [Russ Cox](https://hachyderm.io/@rsc) shed some light on a controversial but important topic: telemetry. How the Go team collects specific build metrics {{< figure src="/img/golab_2024/IMG_20241112_101913.jpg" height=400em caption="Russ Cox" >}} 

- [Alessio Greggi](https://golab.io/speakers/greggi) from [SUSE](https://www.suse.com) gave a presentation with a demo about automatic creation of [SECCOMP profiles](https://en.wikipedia.org/wiki/Seccomp) using many different tools, like strace and [Harpoon](https://github.com/alegrey91/harpoon). {{< figure height=300 src="/img/golab_2024/IMG_20241112_115519.jpg" link="/img/golab_2024/IMG_20241112_115519.jpg" caption="Alessio Greggi" >}}
- [Tomáš Sedláček](https://www.linkedin.com/in/tomasedlacek/) got in the deep of design reasons for choosing sync or async I/O communication.
- [Roberto Clapis](https://twitter.com/empijei) held a workshop on secure coding and talked about defensive approach especially when parsing unknown complex input data.
- [Alan Donovan](https://github.com/adonovan) explained how they managed to scale [gopls](https://pkg.go.dev/golang.org/x/tools/gopls) (the Go Language Server) performance by an order of magnitude (10x).

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_104428.jpg" link="/img/golab_2024/IMG_20241113_104428.jpg" caption="Coffee Breaks and networking time!" >}}

- [Teea Alarto](https://twitter.com/TeeaTime) talked about a practical and effective approach on using generics (a relatively young feature of the Go Language) to write more robust and simple code.
- [Ron Evans](https://twitter.com/deadprogram) made us travel through time with a "Back to the future" mood (12th november, hint hint): the keynote included [tinyGo](https://tinygo.org/) powered flying drones, video capture and streaming with facial recognition and a panel of evil LLM "talking heads" about humanity's future; check out the [video recording](https://www.youtube.com/watch?v=T-U98y-mlIs).

{{< youtube T-U98y-mlIs >}}

At the end of this long day, we celebrated the 15th year of Go with a proper Birthday Party! 🎂

 {{< figure height=300 src="/img/golab_2024/IMG_20241112_175133.jpg" link="/img/golab_2024/IMG_20241112_175133.jpg" target="_blank" caption="tin-foil hat Ron Evans, moderating the automated LLM panel" >}}


### Day two

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_084532.jpg" link="/img/golab_2024/IMG_20241113_084532.jpg" target="_blank" caption="Walking to the conference, on Arno's bank in a sunny autumn morning" >}}

- [Josephine Winter](https://www.linkedin.com/in/josiewinter/) started with an ideal continuity from the previous day by showing her project to automate her pet's daily routine using Arduino and TinyGo with a real-life example of opening a kennel door and releasing dog food.

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_100311.jpg" link="/img/golab_2024/IMG_20241113_100311.jpg" target="_blank" caption="Josephine just before presenting her dog" >}}

- [Jan Mercl](https://gitlab.com/cznic) showed us how is possible to avoid cGo and create a pure Go *sqlite* using the C to Go compiler/transpiler (modernc.org/ccgo/v4) and the runtime support emulating the C libc (modernc.org/libc).

- [Davide Imola](https://twitter.com/DavideImola) jumped in an adventure among the lands of Domain Driven Design. 

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_110218.jpg" link="/img/golab_2024/IMG_20241113_110218.jpg" target="_blank" caption="Davide Imola" >}}

- [Michele Caci](https://www.linkedin.com/in/michele-caci-47770132/) engaged us with his passion for box games, particularly Ticket to Ride, and used it as a cue to give us a review of graph theory.

{{< figure height=300 src="/img/golab_2024/IMG_20241113_122749.jpg" link="/img/golab_2024/IMG_20241113_122749.jpg" target="_blank" caption="playing Ticket to Ride in Go" >}}

- [Federico Paolinelli](https://twitter.com/fedepaol) gave an overview of the tools Go offers out of the box for unit testing our applications and proposed a set of new techniques to write more coherent and understandable tests that fit well in a Go project.

{{< figure height=300 src="/img/golab_2024/IMG_20241113_140614.jpg" link="/img/golab_2024/IMG_20241113_140614.jpg" target="_blank" caption="fundamentals about Go tests" >}}

- [Jesús Espino](https://linkedin.com/in/jesus-espino/) delivered a very deep and low level detailed analysys of a Go ELF binary, the purpose of each section and how to reduce the size of our binaries. 
- [Takuto Nagami](https://www.linkedin.com/in/takutonagami/) talked about his pure-go [resigif](https://github.com/logica0419/resigif) library to resize animated gifs, achieving significant performance improvement over classic tools like imagemagick. 

{{< figure height=300 src="/img/golab_2024/IMG_20241113_153718.jpg" link="/img/golab_2024/IMG_20241113_153718.jpg" target="_blank" caption="resizing animated GIFs without external tools" >}}

- last but not least, there was even time for many interesting lightning talks... 

{{< figure height=300 src="/img/golab_2024/IMG_20241113_164917.jpg" link="/img/golab_2024/IMG_20241113_164917.jpg" target="_blank" caption="Otter for frontend development" >}}

## Takeaways

- Go's balance of legacy and innovation really struck me. Seeing how it's matured while staying true to its core principles is inspiring. It's a testament to the language's design and the community driving it forward. This makes me even more excited to see where Go is headed next!

{{< figure height=300 src="/img/golab_2024/IMG_20241113_170337.jpg" link="/img/golab_2024/IMG_20241113_170337.jpg" target="_blank" caption="How was Go 10 years ago?" >}}

- The Go community is truly something special. Meeting so many passionate and helpful people was a highlight. It reinforces the idea that a language is more than just syntax; it's about the people who use it and build amazing things together.

- One of my biggest takeaways was diving deep into Go's testscripts. They offer such a powerful way to not only test code but also to document examples and usage patterns. I'm definitely going to be integrating testscripts more into my workflow.

- The lightning talks were a goldmine! The concept of using command context to cancel long-running commands really blew me away. It's such an elegant solution to a common problem, and I can't wait to experiment with it in my own projects.

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_173725.jpg" link="/img/golab_2024/IMG_20241113_173725.jpg" caption="See you soon!" >}}
