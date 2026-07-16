---
layout: post
title: "Introduzione al packaging delle applicazioni Rust"
description: "Come pacchettizzare un'applicazione Rust su openSUSE"
categories: linux
tags: [linux, sysadmin, rust, opensuse, packaging, rpm]
author: Andrea Manzini
date: 2024-01-19
---

## 🦀 Introduzione 🦀

Come esercizio, oggi pacchettizzeremo un gioco chiamato `battleship-rs` sviluppato da [Orhun Parmaksız](https://orhun.dev/). Useremo inoltre la potenza di [openSUSE build service](https://build.opensuse.org/) per svolgere la maggior parte del lavoro pesante.

Prima di iniziare, diamo un'occhiata al progetto: è ospitato su [GitHub](https://github.com/orhun/battleship-rs) e, se volete provarlo prima di pacchettizzarlo, è un simpatico gioco in cui due persone possono giocare nel terminale tramite una connessione di rete TCP. Il posizionamento iniziale delle navi, il tracciamento dei colpi, i turni dei giocatori e lo stato stesso del gioco sono gestiti da un singolo processo Rust. 

Per la pacchettizzazione vera e propria, seguiremo la documentazione di riferimento sulla [wiki di openSUSE](https://en.opensuse.org/openSUSE:Packaging_Rust_Software).

## 📦 Prerequisiti

Seguendo le [linee guida di OBS](https://en.opensuse.org/openSUSE:Build_Service_Tutorial), configuriamo il nostro client `osc` con una configurazione minima:

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

## 🛠️ Configurazione del progetto OBS

Ora possiamo spostarci nella nostra directory di sviluppo e creare un sottoprogetto all'interno della nostra cartella home:

```bash
$ cd osc
$ cd home:amanzini
$ osc mkpac battleship-rs 
A    battleship-rs
$ cd battleship-rs
```

## 🍲 Configurare il sistema di build

Per compilare correttamente un pacchetto Rust, abbiamo bisogno di tre elementi:

1. un file `.spec`
2. un file `_service`
3. un file `cargo_config`

Il primo è il classico `.spec` di RPM, la ricetta di cui abbiamo bisogno per preparare qualsiasi pacchetto `rpm`. Sfruttiamo alcune macro per rendere il processo fluido e semplice. Questo mi fa anche notare che non esiste ancora un evidenziatore di sintassi in Hugo per i file `spec`...🤨

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

Il secondo elemento è quello in cui avviene la vera magia. Usando questo file di configurazione, `OBS` è in grado di eseguire molti `servizi` (services) sul nostro progetto. Prima di tutto, può effettuare il checkout dell'esatta versione da *git* e generare per noi un file `.changes` con i messaggi di commit. Successivamente, può creare un archivio compresso dei sorgenti ed eseguire un task speciale [`cargo vendor`](https://doc.rust-lang.org/cargo/commands/cargo-vendor.html) che si occupa di rendere disponibili offline tutte le nostre dipendenze per la compilazione: 


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

~~L'ultimo elemento di cui abbiamo bisogno è un piccolo file che indica al sistema di build di Rust di utilizzare le dipendenze **vendored** (locali), invece di scaricarle da Internet.~~


```bash
$ cat cargo_config
```

```toml
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
```

**Aggiornamento:** con la nuova versione, `cargo_config` viene creato automaticamente e non è più necessario come risorsa esterna, come si può vedere eseguendo il servizio:

```
...
This rewrite introduces some small changes to how vendoring functions for your package.

* cargo_config is no longer created - it's part of the vendor.tar now
    * You can safely remove lines related to cargo_config from your spec file
...
```

## 🚢 Recupero dei sorgenti a monte e invio a OBS

I seguenti comandi provvederanno a:
 - eseguire i servizi per svolgere i task (questo creerà due archivi .zst)
 - aggiungere tutti i file, inclusa la configurazione, al versionamento di OBS
 - inviare tutto al server di build

```bash
$ osc service runall
$ osc addremove
$ osc checkin
```

In teoria abbiamo finito, la compilazione si avvierà su un worker OBS e potremo controllare il log di build; se vogliamo provare tutto localmente, siamo pronti a farlo:

## 🏗️ Compilazione locale 🏗️

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

## 🎮 Proviamo l'installazione 

Dato che abbiamo appena pacchettizzato un gioco, perché non provarlo?

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

ora il pacchetto è installato, possiamo provarlo; sul \"server\" vedremo il campo di battaglia e le connessioni dei client:

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
2  • • • • • • • • • 10 
3  • • • • • • • • • 10 
4  ▭ ▭ • • • • • • • • 
5  • • • • • • • • 10 • 
6  • • • • • • • • 10 • 
7  • • • • • • ▭ ▭ • • 
8  • • • • • • • • • • 
9  • • • • • • • • • • 
10 • • • • • • • • • • 

[#] Game is starting.
[#] Andrea's turn.
```

per giocare sul serio, dobbiamo aprire due terminali diversi e contattare il server, non è permesso barare :)

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
2  • • • • • • • • • 10 
3  • • • • • • • • • 10 
4  ▭ ▭ • • • • • • • • 
5  • • • • • • • • 10 • 
6  • • • • • • • • 10 • 
7  • • • • • • ▭ ▭ • • 
8  • • • • • • • • • • 
9  • • • • • • • • • • 
10 • • • • • • • • • • 
Andrea's turn.
```
## 🎇 Considerazioni finali 🎇

Prima di tutto, grazie a [Orhun Parmaksız](https://orhun.dev/) per aver scritto questo fantastico gioco da terminale! 

Se volete migliorare come manutentori di pacchetti, non perdetevi questa eccellente [guida](https://github.com/jubalh/awesome-package-maintainer) di Michael Vetter. 

Ulteriori dettagli sulla storia e sulle scelte dietro la pacchettizzazione di Rust in openSUSE si trovano nel [talk di William Brown alla RustConf 2022](https://youtu.be/ppJCeAhpx7E) {{< youtube ppJCeAhpx7E >}}

Altri tutorial sulla pacchettizzazione sono disponibili sul canale YouTube di openSUSE: https://www.youtube.com/opensuse

Potete trovare tutti i file e il progetto nella mia cartella home sull'[openSUSE build service](https://build.opensuse.org/package/show/home:amanzini/battleship-rs). Buon hacking!
