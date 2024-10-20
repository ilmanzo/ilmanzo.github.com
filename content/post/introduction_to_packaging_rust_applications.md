---
layout: post
title: "Introduction to packaging Rust application"
description: "How to package a Rust application on openSUSE"
categories: linux
tags: [linux, sysadmin, rust, opensuse, packaging, rpm]
author: Andrea Manzini
date: 2024-01-19
---

## 🦀 Intro 

As an exercise, today we are going to package a game named `battleship-rs` developed by [Orhun Parmaksız](https://orhun.dev/). We will also use the power of [OpenSUSE build service](https://build.opensuse.org/) to do most of the heavy work.

Before starting, let's check out the project: it's hosted on [github](https://github.com/orhun/battleship-rs) and if you want to try it out before packaging, it's a nice game where two people can play in the terminal over a TCP network connection. The initial ship placement, shot tracking, player turns and game state itself is managed from a single Rust process. 

For the actual packaging, we will follow the reference documentation on [openSUSE wiki](https://en.opensuse.org/openSUSE:Packaging_Rust_Software).

## 📦 Prerequisites 

Following the [OBS guidelines](https://en.opensuse.org/openSUSE:Build_Service_Tutorial), let's setup our `osc` client with a minimal configuration:

```bash
$ grep -v '^#' /home/andrea/.config/osc/oscrc

[general]
apiurl = https://api.opensuse.org
ccache = 1
extra-pkgs = vim gdb strace less unzip procps psutils psmisc
show_download_progress = 0

[https://api.opensuse.org]
user=YOURUSERNAME
pass=YOURPASSWORD
```

## 🛠️ OBS project setup 

Now we can switch to our development directory and create a subproject inside our home folder:

```bash
$ cd osc
$ cd home:amanzini
$ osc mkpac battleship-rs 
A    battleship-rs
$ cd battleship-rs
```

## 🍲 Configure build system 

To properly build a Rust package, we need three items:

1. a `.spec` file
2. a `_service` file
3. a `cargo_config` file

The first one is the classic RPM `.spec`, the recipe we need for cooking any `rpm` package. We leverage some macros to make the process smooth and easy. This also makes me notice there isn't yet a syntax highlighter in Hugo for `spec` files...🤨

```bash
$ cat battleship-rs.spec 
```
```ini
Name:           battleship-rs
#               This will be set by osc services, that will run after this.
Version:        0.1.1~0
Release:        0
Summary:        Battleship game implemented in Rust.
License:        MIT
Url:            https://github.com/orhun/battleship-rs
Source0:        %{name}-%{version}.tar.zst
Source1:        vendor.tar.zst
Source2:        cargo_config
BuildRequires:  cargo-packaging
# Disable this line if you wish to support all platforms.
# In most situations, you will likely only target tier1 arches for user facing components.
ExclusiveArch:  %{rust_tier1_arches}

# the name of the actual binary program when differs from the project
%define bin_name battleship

%description
A Battleship game implemented in Rust.
Mainly for package practice

%prep
# The number passed to -a (a stands for "after") should be equivalent to the Source tag number
# of the vendor tarball, 1 in this case (from Source1).
%autosetup -p1 -a1
install -D -m 644 %{SOURCE2} .cargo/config
# Remove exec bits to prevent an issue in fedora shebang checking. Uncomment only if required.
# find vendor -type f -name \*.rs -exec chmod -x '{}' \;

%build
%{cargo_build}

%install
# using cargo_install (only supports bindir)
# %{cargo_install}
# manual process
install -D -d -m 0755 %{buildroot}%{_bindir}
install -m 0755 %{_builddir}/%{name}-%{version}/target/release/%{bin_name} %{buildroot}%{_bindir}/%{bin_name}

# this is useful if you want to run the program internal test suite 
%check
%{cargo_test}

%files
%{_bindir}/%{bin_name}
%license LICENSE
%doc README.md

%changelog
```

The second one is where the real magic happens. Using this configuration file, `OBS` is able to run many `services` on our project. First of all, it can checkout the exact version from *git* and generate for us a `.changes` file with the commit messages. Then it can build a compressed archive of the sources and run a special [`cargo vendor`](https://doc.rust-lang.org/cargo/commands/cargo-vendor.html) task that manages to make all our dependencies available for an offline build: 


```bash
$ cat _service
```
```xml
<services>
  <service mode="disabled" name="obs_scm">
    <param name="url">https://github.com/orhun/battleship-rs.git</param>
    <param name="versionformat">@PARENT_TAG@~@TAG_OFFSET@</param>
    <param name="scm">git</param>
    <param name="revision">v0.1.1</param>
    <param name="match-tag">*</param>
    <param name="versionrewrite-pattern">v(\d+\.\d+\.\d+)</param>
    <param name="versionrewrite-replacement">\1</param>
    <param name="changesgenerate">enable</param>
    <param name="changesauthor">andrea.manzini@suse.com</param>
  </service>
  <service mode="disabled" name="tar" />
  <service mode="disabled" name="recompress">
    <param name="file">*.tar</param>
    <param name="compression">zst</param>
  </service>
  <service mode="disabled" name="set_version"/>
  <service name="cargo_vendor" mode="disabled">
     <param name="src">battleship-rs</param>
     <param name="compression">zst</param>
     <param name="update">true</param>
  </service>
</services>
```

~~The last item we need is a small file that instructs Rust build system to use **vendored** dependencies, instead of downloading from the internet.~~


```bash
$ cat cargo_config
```

```toml
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
```

**Update:** with the new release, che `cargo_config` is automatically created and no more needed as external asset, as you can see running the service:

```
...
This rewrite introduces some small changes to how vendoring functions for your package.

* cargo_config is no longer created - it's part of the vendor.tar now
    * You can safely remove lines related to cargo_config from your spec file
...
```

## 🚢 Fetch upstream source and check in to OBS

The following commands will 
 - run the services to execute the tasks (this will create two .zst archives)
 - add all the files, included the configuration, to OBS versioning
 - send everything to the build server

```bash
$ osc service runall
$ osc addremove
$ osc checkin
```

Potentially we are done, build will start on a OBS worker and we can check the build log; If we want to try everything locally, we are ready to

## 🏗️ Local build 

```bash
$ osc build 
```
```
Building battleship-rs.spec for openSUSE_Tumbleweed/x86_64

... [lots of output omitted] ...

build: extracting built packages...
RPMS/x86_64/battleship-rs-0.1.1~0-0.x86_64.rpm
SRPMS/battleship-rs-0.1.1~0-0.src.rpm
OTHER/_statistics
OTHER/rpmlint.log
```

## 🎮 Let's test installation 

Since we just packaged a game, why not give it a try ?

```bash
$ sudo zypper in battleship-rs-0.1.1~0-0.x86_64.rpm
```
```
Refreshing service 'openSUSE'.................................................[done]
Loading repository data...
Reading installed packages...
Resolving package dependencies...

The following NEW package is going to be installed:
  battleship-rs

1 new package to install.
Overall download size: 223.4 KiB. Already cached: 0 B. After the operation, additional 574.3 KiB will be used.
Continue? [y/n/v/...? shows all options] (y): 
Retrieving: battleship-rs-0.1.1~0-0.x86_64 (Plain RPM files cache)                                        (1/1), 223.4 KiB    
battleship-rs-0.1.1~0-0.x86_64.rpm:
    Package header is not signed!

battleship-rs-0.1.1~0-0.x86_64 (Plain RPM files cache): Signature verification failed [6-File is unsigned]
Abort, retry, ignore? [a/r/i] (a): i

Checking for file conflicts: .................................................[done]
(1/1) Installing: battleship-rs-0.1.1~0-0.x86_64 .............................[done]
Running post-transaction scripts .............................................[done]
```

now the package is installed, we can try it out; on the 'server' we will see the battlefield and client connections:

```bash
$ battleship  
[+] Server is listening on 127.0.0.1:1234
[+] New connection: 127.0.0.1:33692
[+] New connection: 127.0.0.1:41104
[#] Andrea's grid:
   A B C D E F G H I J 
1  • • • • • • • • • • 
2  • • • • • • ▭ ▭ • • 
3  • • • • • • • ▭ ▭ • 
4  • • • • • • • • • • 
5  • ▧ ▧ • • • • • • • 
6  • ▧ ▧ • • • • • • • 
7  • ▧ ▧ • • • • • • • 
8  • • • • • • • • • • 
9  • • △ △ ▭ ▭ ▭ ▭ • • 
10 • • • • • • • • • • 

[#] ilmanzo's grid:
   A B C D E F G H I J 
1  • • • • • • • • • • 
2  • • • • • • • • • ▯ 
3  • • • • • • • • • ▯ 
4  ▭ ▭ • • • • • • • • 
5  • • • • • • • • ▯ • 
6  • • • • • • • • ▯ • 
7  • • • • • • ▭ ▭ • • 
8  • • • • • • • • • • 
9  • • • • • • • • • • 
10 • • • • • • • • • • 

[#] Game is starting.
[#] Andrea's turn.
```

to actually play the game, we need to spawn two different terminals and contact the server, no cheating allowed :)

```bash
$ nc 127.0.0.1 1234
        _    _
     __|_|__|_|__
   _|____________|__
  |o o o o o o o o /
~'`~'`~'`~'`~'`~'`~'`~
Welcome to Battleship!
Please enter your name: ilmanzo
Your opponent is Andrea
Game starts in 3...
Game starts in 2...
Game starts in 1...

   A B C D E F G H I J 
1  • • • • • • • • • • 
2  • • • • • • • • • • 
3  • • • • • • • • • • 
4  • • • • • • • • • • 
5  • • • • • • • • • • 
6  • • • • • • • • • • 
7  • • • • • • • • • • 
8  • • • • • • • • • • 
9  • • • • • • • • • • 
10 • • • • • • • • • • 

   A B C D E F G H I J 
1  • • • • • • • • • • 
2  • • • • • • • • • ▯ 
3  • • • • • • • • • ▯ 
4  ▭ ▭ • • • • • • • • 
5  • • • • • • • • ▯ • 
6  • • • • • • • • ▯ • 
7  • • • • • • ▭ ▭ • • 
8  • • • • • • • • • • 
9  • • • • • • • • • • 
10 • • • • • • • • • • 
Andrea's turn.
```
## 🎇 Final toughts

First of all, thanks to [Orhun Parmaksız](https://orhun.dev/) for writing an awesome terminal game! 

If you want to get better as packager be sure to read this excellent [guide](https://github.com/jubalh/awesome-package-maintainer) from Michael Vetter. 

More details on the history and choices behind Rust packaging in openSUSE are in [William Brown's talk on RustConf 2022](https://youtu.be/ppJCeAhpx7E) {{< youtube ppJCeAhpx7E >}}

More packaging tutorials on OpenSUSE YouTube channel: https://www.youtube.com/opensuse

You can find all the files and the project in my home folder on the [openSUSE build service](https://build.opensuse.org/package/show/home:amanzini/battleship-rs). Happy hacking!

