---
layout: post
description: "Mid-2026 recap: coding, conferences, and security workshops"
title: "Mid 2026 recap: coding, conferences, and workshops"
categories: conference
tags: [uyuni, opensuse, conference, flatpak, distrobox, ai, systemd, security]
author: Andrea Manzini
date: 2026-06-14
---

## 📝 Too Long; Didn't Read

We are already at the halfway mark of 2026, and these first six months have been intense. Between coding, conferences, and workshops across Europe, I worked on systems management, green computing, local AI, and software security. This post is a recap of the projects and talks that shaped my February-to-June journey.

---

## 🛠️ February to May: deep dive into the Uyuni project

For the first four months of this year, my main engineering focus was almost entirely dedicated to the fascinating world of the Uyuni project. If you have not had a chance to work with it yet, Uyuni is an incredibly powerful, completely open-source configuration and infrastructure management solution. It originally started as an evolution of Spacewalk, and today it serves as the upstream community project that feeds directly into SUSE Multi-Linux Manager, which was formerly known as SUSE Manager.

![uyuni](/img/mid2026/uyuni_logo.png)

The core magic of Uyuni lies in its deep integration with Salt, also known as SaltStack. This integration allows administrators to manage, patch, and configure thousands of machines in real time. It is a true lifesaver when you are dealing with massive, complex environments because it can handle everything from automated package deployment to security auditing through OpenSCAP. What makes it even cooler is its multi-distribution support, which means you can manage openSUSE, SUSE Linux Enterprise, Red Hat Enterprise Linux, Rocky Linux, Debian, and Ubuntu all from a single, unified dashboard.

In addition to all the core package and Salt work, I had the pleasure of hosting an internal SELinux knowledge sharing session. SELinux can often feel like a bit of a dark art for systems administrators, so we walked through practical, real-world troubleshooting, label management, and policy generation to demystify how it secures our infrastructure and client communication paths. It was really rewarding to see team members gain confidence in handling security policies instead of just putting SELinux in permissive mode.

Check out the [Uyuni project website](https://www.uyuni-project.org/) and the [Uyuni GitHub repository](https://github.com/uyuni-project/uyuni) to see what it's all about.

---

## 🌿 April 20 to 25: susecon Prague & openSUSE developer summit

Near the end of April, I packed my bags and headed to the absolutely gorgeous city of Prague to attend SUSECON 2026. This was an extra special trip because the openSUSE Developer Summit, often referred to as ODS 2026, was co-located with the main conference. This setup created an incredible double feature where enterprise developers and open-source community members could hang out, share ideas, and collaborate on the next generation of Linux technologies.

![ods](/img/mid2026/opendevsummit.png)

### Green computing & community innovation
Among the many inspiring themes discussed during the event, green computing and environmental sustainability in IT were especially close to my heart, and they were also the focus of my talk. With modern data centers consuming a massive and ever-growing share of global electricity, finding ways to make our infrastructure more power-efficient has become an absolute necessity. During the presentations and hallway tracks, we had some fantastic, deeply technical conversations about how we can optimize everything from the Linux kernel to containerized workloads to minimize our carbon footprints.

![kepler](/img/mid2026/energy-for-namespace.png)

If you want to read more about the event, you can visit the official SUSECON 2026 event website at https://www.susecon.com/ and find more details on the openSUSE Developer Summit page at https://events.opensuse.org/conferences/ODS26. I also uploaded my presentation slides on green computing and systems optimization, and you can view them [here](https://ilmanzo.github.io/suse_presentations/green_computing_from_cli/energy_talk_en.html)

---

## 🐧 May 23: Linux day SE Mantova (flatpak & distrobox)

In late May, I had the wonderful opportunity to return to local community events by speaking at the Linux Day Special Edition in the historic city of Mantova, Italy. There is always something incredibly special about local user groups, and this event was no exception, filled with enthusiastic users, developers, and open-source fans. My talk for this session was focused on how we can modernize our desktop application delivery and our developer workspaces using Flatpak and Distrobox.

![ld2026se](/img/mid2026/photo_2026-06-14_10-55-41.jpg)

### Why flatpak + distrobox?
Flatpak has completely changed the game for desktop applications on Linux by providing a secure, isolated, and distribution-agnostic packaging format. It effectively solves the old problem of dependency conflicts, meaning you can run the latest desktop apps on any distribution without worrying about breaking your system libraries. On the other side of the coin, Distrobox is an amazing tool for command line work. It lets you run any Linux distribution inside your terminal by using containers through Podman or Docker. This means a developer can seamlessly run tools and libraries from Arch, Fedora, Debian, or Ubuntu directly on their host system without cluttering up their main operating system.

When you combine these two technologies, they create a highly flexible, incredibly robust environment that is perfect for modern immutable operating systems. I had a blast demonstrating how these tools work together, showing how easy it is to set up an entire development environment in seconds.

You can find more information about the venue and the organizers, with slides and recording on the Linux Day Mantova [event page](https://www.lugman.org/Linux_day_2026_SE).

---

## 🤖 May 25 to 29: Nuremberg AI workshop

Immediately after the event in Mantova, I traveled to Nuremberg, Germany, to spend a full week at an intensive AI workshop. Since the flight schedules were a bit tricky, I actually flew into Munich first and then caught a highly scenic train ride up to Nuremberg. It was a wonderful transition from the Italian sunshine to the rolling hills of Bavaria.

On the technical side of things, this workshop was a deep dive into local-first artificial intelligence, open-weight language models, and the practical challenges of deploying these models on our own hardware. We spent five packed days hacking on a variety of cutting-edge artificial intelligence architectures. One of our main areas of focus was model quantization, where we worked on reducing the size of large models using formats like GGUF and EXL2 so that we could run massive 70-billion parameter models on consumer-grade hardware or small local server arrays. We also spent a lot of time building low-latency document search pipelines using retrieval-augmented generation, commonly known as RAG, integrated with high-performance vector databases.

---

## ⚡ June 6: GDG DevFest Vicenza (5+1 systemd features you should know)

In early June, I stayed closer to home and joined the fantastic community at GDG DevFest Vicenza 2026 in the beautiful Veneto region. I was invited to give a closing talk, and I decided to speak on a topic that is controversial in the linux community: systemd. My presentation was titled "5+1 systemd features you should know".

![devfest](/img/mid2026/dev_fest_doodled.png)

A lot of developers tend to think of systemd as just a basic tool for starting and stopping services, but it actually contains a treasure trove of built-in features that can replace a lot of complicated external utilities. In my talk, I walked the audience through six of my favorite tricks. We discussed systemd-socket-activate for setting up on-demand service startup, and we looked at how systemd-analyze plot can generate a beautiful visual chart to help optimize system boot times. We also talked about using DynamicUser to run services with completely sandboxed, ephemeral users for maximum security, and how to use configuration drop-in files to extend service files without touching the main configuration. Finally, we covered how systemd can manage standard directories using RuntimeDirectory or StateDirectory, and we looked at systemd-sysext, which allows for seamless, non-destructive system extensions.

To give you an idea of how incredibly simple it is to set up a secure service with sandbox features using systemd, here is a quick snippet of a service file that enables DynamicUser and sets up isolated state directories automatically:

```ini
[Unit]
Description=My secure local sandbox service

[Service]
ExecStart=/usr/bin/my-cool-app
DynamicUser=yes
StateDirectory=my-cool-app
RuntimeDirectory=my-cool-app
ProtectSystem=strict
ProtectHome=yes
```

With just those few lines, systemd manages a completely ephemeral user, isolates the home directories, blocks write access to the system, and mounts clean runtime and state directories for your app. The energy at the DevFest was incredible, and I had some great conversations with web and mobile developers who were surprised to see how much systemd could simplify their deployment pipelines. You can check out the GDG DevFest Vicenza website at https://devfest.gdgvicenza.it/ .

---

## 🔒 June 8 to 11: Helsinki security workshop

To bring this busy season of travel to a close, I spent the second week of June in Helsinki, Finland, participating in the Helsinki Security Workshop. This event brought together system engineers, security researchers, and core developers from all over the Europe.

Traveling further north to Finland in June was an absolute delight, especially since we were welcomed by uncharacteristically warm and beautiful summer weather. The cool, refreshing breeze blowing in from the Baltic Sea was incredibly rejuvenating. Since it was the season of the famous Nordic white nights, where the sun barely sets and the evenings remain bright and luminous, we had endless hours of daylight to enjoy. We made sure to take full advantage of this with some wonderful outdoor team activities. 

![hels1](/img/mid2026/hels1.jpg)
![hels2](/img/mid2026/hels2.jpg)
![hels3](/img/mid2026/hels3.jpg)

---

## 🌅 Looking ahead

Looking back at these first six months of 2026, I feel grateful for all the opportunities I had to learn, code, travel, and share ideas. This half of the year has really highlighted how important the three pillars of automation, environmental sustainability, and deep security are to the future of our industry.

I want to say a huge thank you to all the amazing organizers, volunteers, fellow speakers, and attendees who made these events so incredibly rewarding and memorable. The open-source community is truly a special place, and it is the people who make it so vibrant and inspiring.

An extra special shout-out to some of the local communities that made this year so memorable. I had a truly fantastic time collaborating and sharing ideas with the awesome folks at [GDG Vicenza](https://gdg.community.dev/gdg-vicenza/), [GDG Venezia](https://gdg.community.dev/gdg-venezia/), [BacaroTech](https://bacarotech.it/), and [Mantova Dev](https://linktr.ee/mantovadev), as well as participating in the wonderful [copiaIncolla Open](https://www.copiaincolla.com/copiaincolla-open) initiative. These local groups are the absolute beating heart of open source, and the sheer energy, curiosity, and warmth they bring to every single meetup and discussion is incredibly inspiring.

Now that the spring conference season is wrapped up, I plan to get back to my desk and spend some serious time writing code and experimenting.

***

### Join the conversation!

I would love to hear about your own experiences and thoughts on these topics. Let us start a discussion in the comments section below:

* **Local AI models:** Have you tried running large language models locally on your own machine? What are your favorite tools and quantization formats?
* **Development setup:** Are you using Flatpak or Distrobox for your daily driver development workflows? How has it changed your environment stability?
* **Systemd power features:** Do you make use of advanced systemd features like DynamicUser or sysext in your services, or do you still treat systemd as a basic service runner?

If you prefer, you can also reach out to me directly on [Mastodon](https://fosstodon.org/@ilmanzo) to share your feedback or ask questions. Let us keep the open-source conversation going!
