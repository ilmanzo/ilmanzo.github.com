---
layout: post
title: "Un viaggio sulla rugginosa D-Bus"
description: "Come esporre un servizio D-Bus e creare un semplice client scrivendo del codice Rust"
categories: linux
tags: [linux, desktop, programming, rust, tutorial, IPC]
author: Andrea Manzini
date: 2023-10-04
---

## Introduzione 🚌

[D-Bus](https://www.freedesktop.org/wiki/Software/dbus/) è un sistema di message bus e uno standard per l'inter-process communication (IPC), utilizzato principalmente nelle applicazioni desktop Linux. Sia [Qt](https://doc.qt.io/qt-6/qtdbus-index.html) che [GLib](https://dbus.freedesktop.org/doc/dbus-glib/) offrono astrazioni di alto livello per la comunicazione D-Bus, e molti dei servizi desktop su cui facciamo affidamento esportano protocolli D-Bus. Anche l'onnipresente **systemd** può essere interfacciato solo tramite l'API D-Bus. Tuttavia, D-Bus ha i suoi difetti, in particolare la mancanza di documentazione aggiornata. In questo articolo esploreremo come scrivere il nostro servizio D-Bus in Rust e collegarlo a un client D-Bus sempre scritto in Rust.

Per iniziare, se volete fare un po' di pratica con D-Bus, vi consiglio [questo tutorial](https://dbus.freedesktop.org/doc/dbus-tutorial.html) e [questo link](https://dbus2.github.io/zbus/concepts.html) se volete rinfrescarvi la memoria sulla nomenclatura e sui concetti di D-Bus.

Tutto il codice si trova nel suo [repository GitHub](https://github.com/ilmanzo/dbus-playground), così potrete seguirlo e provarlo voi stessi. Buon viaggio!

![toy-bus](/img/pexels-nubia-navarro-(nubikini)-385997.jpg)
Crediti immagine: [Nubia Navarro](https://www.pexels.com/@nubikini/)

## Il Servizio

Il servizio che esporremo sarà molto semplice: una volta chiamato, terrà traccia di quante volte è stato invocato e dell'ultima data/ora di chiamata. Potremo anche passare il nostro nome come parametro, giusto per mostrare come funziona il passaggio dei parametri.

Grazie a una [fantastica crate Rust](https://docs.rs/zbus/latest/zbus/), creare un servizio D-Bus è piuttosto semplice. Abbiamo scelto di renderlo asincrono, perché... Perché no? 

La funzione principale risiede nell'implementazione del trait:

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

## Proviamolo!

Compiliamo l'intero progetto con:

```bash
$ cargo build --release
```

Successivamente possiamo eseguire il binario del servizio, che rimarrà in attesa di connessioni:

```bash
$ target/release/service
```

Con il servizio in esecuzione, possiamo ispezionarlo e interrogarlo utilizzando qualsiasi client D-Bus, come [D-Feet](https://wiki.gnome.org/Apps/DFeet) o `busctl`:

```bash
$ SVC=org.zbus.MyService
$ busctl --user call $SVC /org/zbus/MyService $SVC CallMe s "Andrea"
s "Hi Andrea, this is the first time you call me!"

$ busctl --user call $SVC /org/zbus/MyService $SVC CallMe s "Andrea"
s "Hello Andrea, I have been called 1 times, last was at Tue, 3 Oct 2023 18:08:16 +0200"

$ busctl --user call $SVC /org/zbus/MyService $SVC CallMe s "Andrea"
s "Hello Andrea, I have been called 2 times, last was at Tue, 3 Oct 2023 18:09:43 +0200"
```

Potete notare la piccola lettera `s` prima del parametro del nome. Si tratta della dichiarazione del tipo di parametro, che segue il [type system](https://dbus.freedesktop.org/doc/dbus-specification.html#type-system) di D-Bus.

Bene, il nostro servizio sembra funcionarci. Potremmo fermarci qui, ma implementiamo anche...

## Il Client

Un semplice client è comodo da avere e aiuterà molto quando vorremo aggiungere test funzionali al nostro progetto.
Inoltre, ci permette di fare pratica con una bella funzionalità di *Cargo* chiamata [`workspaces`](https://doc.rust-lang.org/book/ch14-03-cargo-workspaces.html), utile per ospitare più binari all'interno dello stesso progetto.

Dato che il codice sorgente è breve, possiamo incollarlo interamente:

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
Dovreste averlo già compilato, quindi, con il servizio in esecuzione, basta lanciare:

```bash
$ target/release/client
"Hello Andrea, I have been called 3 times, last was at Tue, 3 Oct 2023 18:19:26 +0200"
```

Sembra che per ora possiamo parcheggiare il bus e terminare qui il nostro viaggio 😊

![rusty-bus](/img/pexels-hans-middendorp-5186993.jpg)
Crediti immagine: [Hans Middendorp](https://www.pexels.com/@hansmiddendorp/)

## Conclusioni

L'implementazione di riferimento a basso livello delle [API di D-Bus](http://dbus.freedesktop.org/doc/api/html/index.html) e il [protocollo](http://dbus.freedesktop.org/doc/dbus-specification.html) D-Bus sono stati ampiamente testati nel mondo reale per diversi anni e sono ormai \"scolpiti nella pietra\". Eventuali modifiche future saranno compatibili o opportunamente versionate.

D-Bus è una tecnologia che ha circa 15 anni, ma è ancora ampiamente utilizzata. Sfortunatamente molti documenti in circolazione sono datati o fuorvianti, quindi può essere utile rinfrescare un po' i concetti e giocare con questo sistema di message bus. Buon hacking!
