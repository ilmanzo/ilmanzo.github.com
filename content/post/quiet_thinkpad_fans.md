---
layout: post
title: "Quiet fans on Thinkpad P15"
description: "How to lower the default fan noise on Thinkpad P15 Gen2"
categories: hardware
tags: [linux, desktop, sysadmin, thinkpad, fan, noise]
author: Andrea Manzini
date: 2023-09-01
---

## Intro

The `Thinkpad P15` laptop is a nice linux machine, but there is an annoying detail, as [Arch wiki](https://wiki.archlinux.org/title/Lenovo_ThinkPad_P15_Gen_1) writes:
*"The default operation of fans is noisy, as they are basically at medium power all the time. The thinkfan program can be used to create a quieter operation, while retaining reasonable temperatures."* . Let's make it quieter.

## Prerequisite

Install [thinkfan](https://github.com/vmatare/thinkfan) rpm package and enable the daemon:
```shell
# zypper in thinkfan && systemctl enable --now thinkfan
```
Make sure modules are loaded at startup with the options to override fan control and enable experimental features:
```shell
$ cat /etc/modules-load.d/thinkpad.conf
thinkpad_acpi
coretemp

$ cat /etc/modprobe.d/thinkpad_acpi.conf
options thinkpad_acpi fan_control=1 experimental=1
```

## Configuration

The daemon configuration consists in a single and short file. On the first part we need to specify the `virtual file` containing the temperatures; then the file which controls the fan speed, and a third section wich maps the `fan level` to the temperature range:

```shell
$ cat /etc/thinkfan.conf 
sensors:
  - tpacpi: /proc/acpi/ibm/thermal
    # Some of the temperature entries in /proc/acpi/ibm/thermal may be
    # irrelevant or unused, so individual ones can be selected:
    indices: [1, 2, 4, 5, 6]

fans:
  - tpacpi: /proc/acpi/ibm/fan

levels:
  - [0, 0, 60]
  - [2, 60, 65]
  - [3, 65, 70]
  - [5, 70, 75]
  - [6, 75, 80]
  - [7, 80, 85]
  - ["level disengaged", 85, 255]
```

## Conclusion

Depending on your system, you can use [many other programs](https://wiki.archlinux.org/title/fan_speed_control) to control fan speed in linux; thinkfan has the advantage to be lightweight and very configurable.

