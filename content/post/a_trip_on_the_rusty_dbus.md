---
layout: post
title: "A trip on the rusty D-Bus"
description: "How to expose a D-Bus service and create a simple client writing some Rust code"
categories: linux
tags: [linux, desktop, programming, rust, tutorial, IPC]
author: Andrea Manzini
date: 2023-10-04
---

## Intro 🚌

[D-Bus](https://www.freedesktop.org/wiki/Software/dbus/) is a message bus system and standard for inter-process communication, mostly used in Linux desktop applications. Both [Qt](https://doc.qt.io/qt-6/qtdbus-index.html) and [GLib](https://dbus.freedesktop.org/doc/dbus-glib/) have high-level abstractions for D-Bus communication, and many of the desktop services we rely on export D-Bus protocols. Also the omnipresent **systemd** can be only interfaced via D-Bus API. However, D-Bus has its shortcomings — namely a lack of documentation. In this article we'll explore how to write our own D-Bus Service in Rust and connect it to our D-Bus client.

As as starter, if you want to get some practice on D-Bus, I recommend [this tutorial](https://dbus.freedesktop.org/doc/dbus-tutorial.html) and [here](https://dbus2.github.io/zbus/concepts.html) you may like to refresh some D-Bus naming and concepts.

All the code lives in its own GitHub [repository](https://github.com/ilmanzo/dbus-playground), so you can follow along and try yourself. Enjoy the trip!

![toy-bus](/img/pexels-nubia-navarro-(nubikini)-385997.jpg)
Image credits to: [Nubia Navarro](https://www.pexels.com/@nubikini/)

## The Service

Our exposed service will be very simple: once called, it will keep track of how many times it has been called and last date/time. We can also pass our name as parameter, just to show how parameter passing works.

Thanks to a [wonderful Rust crate](https://dbus.pages.freedesktop.org/zbus/), creating D-Bus service is rather easy. We opt to make it async, because... Why not ? 

The core function is the trait implementation:

```Rust
struct MyService {
    call_count: u64,
    call_timestamp: Option<DateTime<Local>>,
}

#[dbus_interface(name = "org.zbus.MyService")]
impl MyService {
    async fn call_me(&mut self, name: &str) -> String {
        let msg = match self.call_count {
            0 => format!("Hi {}, this is the first time you call me!", name),
            _ => format!(
                "Hello {}, I have been called {} times, last was at {}",
                name,
                self.call_count,
                self.call_timestamp
                    .expect("unable to get local time")
                    .to_rfc2822()
            ),
        };
        self.call_count += 1;
        self.call_timestamp = Some(Local::now());
        msg
    }
}
```

## Let's try it out

Compile the whole project with 

```bash
$ cargo build --release
```

Then you can run the service binary, which will block waiting for connections

```bash
$ target/release/service
```

With the service running, we can inspect and probe it using any D-Bus client, such as [D-Feet](https://wiki.gnome.org/Apps/DFeet) or `busctl`

```bash
$ SVC=org.zbus.MyService
$ busctl --user call $SVC /org/zbus/MyService $SVC CallMe s "Andrea"
s "Hi Andrea, this is the first time you call me!"

$ busctl --user call $SVC /org/zbus/MyService $SVC CallMe s "Andrea"
s "Hello Andrea, I have been called 1 times, last was at Tue, 3 Oct 2023 18:08:16 +0200"

$ busctl --user call $SVC /org/zbus/MyService $SVC CallMe s "Andrea"
s "Hello Andrea, I have been called 2 times, last was at Tue, 3 Oct 2023 18:09:43 +0200"
```

You can notice the small `s` character before the name parameter. This is the parameter type declaration, following the D-Bus [type system](https://dbus.freedesktop.org/doc/dbus-specification.html#type-system)

Well, our service seems working, we could stop here but let's also implement ...

## The Client

A simple client is nice to have and will help a lot when we want to add functional testing to our project.
Also it makes us exercise a nice *Cargo* feature named [`workspaces`](https://doc.rust-lang.org/book/ch14-03-cargo-workspaces.html) to host multiple binaries inside the same project.

Since source code is short we can paste as a whole:

```Rust
use zbus::{dbus_proxy, Connection, Result};

#[dbus_proxy(
    interface = "org.zbus.MyService",
    default_service = "org.zbus.MyService",
    default_path = "/org/zbus/MyService"
)]
trait MyService {
    async fn call_me(&self, name: &str) -> Result<String>;
}

#[tokio::main]
async fn main() -> Result<()> {
    let connection = Connection::session().await?;
    // `dbus_proxy` macro creates `MyServiceProxy` based on `Notifications` trait.
    let proxy = MyServiceProxy::new(&connection).await?;
    let reply = proxy.call_me("Andrea").await?;
    println!("{reply}");

    Ok(())
}
```
You should have it already compiled, so with the service running, just issue a

```bash
$ target/release/client
"Hello Andrea, I have been called 3 times, last was at Tue, 3 Oct 2023 18:19:26 +0200"
```

Looks like we can park the bus for now and stop our journey here 😊

![rusty-bus](/img/pexels-hans-middendorp-5186993.jpg)
Image credits to [Hans Middendorp](https://www.pexels.com/@hansmiddendorp/)

## Conclusion

The D-Bus low-level [API reference implementation](http://dbus.freedesktop.org/doc/api/html/index.html) and the D-Bus [protocol](http://dbus.freedesktop.org/doc/dbus-specification.html) have been heavily tested in the real world over several years, and are now "set in stone." Future changes will either be compatible or versioned appropriately.

D-Bus is ~15y old technology, but still in use. Unfortunately many documents out there are sometime aging or misleading so it can be helpful to refresh it a bit and play with this message bus system. Happy Hacking!


