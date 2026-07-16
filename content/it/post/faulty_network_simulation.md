---
layout: post
title: "Fault Injection in Network Namespace e ambienti Veth"
description: "Come migliorare il proprio software simulando un dispositivo di rete guasto o lento"
categories: linux
tags: [linux, sysadmin, programming, testing, device, network, namespace]
author: Andrea Manzini
date: 2024-01-06
---

## Introduzione

Questo articolo fa seguito al mio [post precedente](https://ilmanzo.github.io/it/post/faulty_disk_simulation/) ed è una sorta di continuazione della serie sull'argomento, in cui esploriamo modi per rendere il nostro sistema di test più \"inaffidabile\" al fine di osservare se le nostre applicazioni si comportano correttamente in ambienti difficili e non ideali.

In questo articolo esploreremo alcune tecnologie Linux:
- Network Namespace (**netns**)
- Dispositivi Ethernet Virtuali (**veth**)
- Politica di scheduling per l'emulazione di rete (**netem**)

L'obiettivo è configurare un collegamento di rete virtuale all'interno del nostro sistema, far comunicare i due dispositivi di rete tra loro e quindi simulare una comunicazione *scadente/lenta/instabile/difettosa* per testare come si comportano le applicazioni in condizioni difficili.

Pronti a giocare e a rompere qualcosa?

![broken network](/img/pexels-broken-net-14839933.jpeg)
Crediti immagine: [Abdulvahap Demir](https://www.pexels.com/@infovahapdmr/)


## Configurazione dei netns

I network namespace rappresentano una tecnologia fondamentale ed essenziale per i container, in quanto consentono di stabilire ambienti di rete segregati all'interno di un sistema Linux. Facilitano la creazione di stack di rete distinti per i processi, incluse interfacce, tabelle di routing e regole del firewall. Questa segregazione garantisce che i processi all'interno di un network namespace rimangano separati e isolati da quelli in altri namespace.

per creare e gestire i `netns` abbiamo solo bisogno del comando `ip`:

```bash
$ ip netns add ns_1
$ ip netns add ns_2
```
Con questi comandi abbiamo appena configurato uno spazio vuoto, ora dobbiamo inserirci qualcosa dentro.

## Configurazione delle ethernet virtuali

I dispositivi veth, acronimo di virtual Ethernet, sono interfacce di rete virtuali doppie impiegate per collegare i network namespace. Ogni coppia è composta da due endpoint: uno all'interno di uno specifico namespace e l'altro in un namespace separato. Queste interfacce virtuali imitano i cavi Ethernet, consentendo una comunicazione fluida tra i namespace interconnessi. Il traffico può attraversare questa coppia veth in modo bidirezionale, facilitando la trasmissione a due vie.

```bash
$ ip link add veth_1 type veth peer name veth_2
$ ip link set veth_1 netns ns_1
$ ip link set veth_2 netns ns_2
$ ip netns exec ns_1 ip link set dev veth_1 up
$ ip netns exec ns_2 ip link set dev veth_2 up
```

nota: `ip netns ns_1 exec COMANDO` è una comoda scorciatoia per eseguire un singolo comando in uno specifico namespace.

All'interno della vostra macchina ci saranno ora *due* nuovi namespace **indipendenti**, ciascuno con la propria scheda di rete virtuale, totalmente separati dall'ambiente dell'*host*:

```
          ┌──────────────────────────────────────────────────────────┐
          │ Linux machine                                            │
          │                                                          │
          │       ┌──────────────┐            ┌──────────────┐       │
          │       │     ns_1     │            │     ns_2     │       │
          │       │              │            │              │       │
          │       │              │            │              │       │
          │       │              │            │              │       │
          │       │              │            │              │       │
          │       │    ┌─────────┤            ├─────────┐    │       │
          │       │    │         │◄───────────┤         │    │       │
          │       │    │  veth_1 │            │ veth_2  │    │       │
          │       │    │         ├───────────►│         │    │       │
          │       │    └─────────┤            ├─────────┘    │       │
          │       │              │            │              │       │
          │       └──────────────┘            └──────────────┘       │
          │                                                          │
          │                                                          │
          └──────────────────────────────────────────────────────────┘
```

## Indirizzamento

Finora i dispositivi virtuali non hanno ancora alcun indirizzo IP, e anche il loopback è disattivato:

```bash 
$ ip -all netns exec ip link show

netns: ns_1
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
9: veth_1@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 52:69:cf:de:7d:10 brd ff:ff:ff:ff:ff:ff link-netns ns_2

netns: ns_2
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
8: veth_2@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 6e:19:3c:20:e0:9a brd ff:ff:ff:ff:ff:ff link-netns ns_1
```

assegniamo loro un IPV4 casuale sulla stessa subnet:

```bash
$ ip netns exec ns_1 ip addr add 10.1.1.1/24 dev veth_1 
$ ip netns exec ns_2 ip addr add 10.1.1.2/24 dev veth_2
```

La cosa fantastica ora è che possiamo raggiungere l'altra estremità solo tramite il namespace. Giusto per essere chiari, questo non funzionerà:

```bash
$ ping -c 3 10.1.1.2 
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.

--- 10.1.1.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2020ms
```

Perché? Perché dobbiamo eseguire il comando `ping` dal namespace corretto:

```bash
$ ip netns exec ns_1 ping -c 3 10.1.1.2
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.
64 bytes from 10.1.1.2: icmp_seq=1 ttl=64 time=0.040 ms
64 bytes from 10.1.1.2: icmp_seq=2 ttl=64 time=0.044 ms
64 bytes from 10.1.1.2: icmp_seq=3 ttl=64 time=0.057 ms

--- 10.1.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2021ms
rtt min/avg/max/mdev = 0.040/0.047/0.057/0.007 ms
```

Guardando quei numeri di RTT (round-trip time), questa rete virtuale sembra funzionare in modo rapido e fluido, quindi è ora di rompere qualcosa... 😈

## Fault injection

Aggiungiamo un ritardo casuale di 50ms ± 25ms a ciascun pacchetto su un lato:  

```bash
$ ip netns exec ns_1 tc qdisc add dev veth_1 root netem delay 50ms 25ms
```
dall'altro lato, simuliamo anche una probabilità del 50% di pacchetti persi, con una probabilità del 25% di perdita dei pacchetti successivi (per emulare perdite di pacchetti a raffica o a burst):

```bash 
$ ip netns exec ns_2 tc qdisc add dev veth_2 root netem loss 50% 25%
```

Come si comporterà il ping? Decisamente *male*: 👎

```bash
$ ip netns exec ns_1 ping -c 10 10.1.1.2
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.
64 bytes from 10.1.1.2: icmp_seq=1 ttl=64 time=66.6 ms
64 bytes from 10.1.1.2: icmp_seq=3 ttl=64 time=34.6 ms
64 bytes from 10.1.1.2: icmp_seq=4 ttl=64 time=41.6 ms
64 bytes from 10.1.1.2: icmp_seq=6 ttl=64 time=28.0 ms
64 bytes from 10.1.1.2: icmp_seq=9 ttl=64 time=51.6 ms
64 bytes from 10.1.1.2: icmp_seq=10 ttl=64 time=50.8 ms

--- 10.1.1.2 ping statistics ---
10 packets transmitted, 6 received, 40% packet loss, time 9081ms
rtt min/avg/max/mdev = 28.031/45.522/66.569/12.561 ms
```

Altre due fantastiche funzionalità di `netem` sono la **corruzione dei pacchetti** (Packet corruption), che simula l'errore di un singolo bit a un offset casuale nel pacchetto, e il **riordinamento dei pacchetti** (Packet Re-ordering), che fa sì che una certa percentuale di pacchetti arrivi in ordine errato. Per qualsiasi dettaglio, potete consultare la [pagina man](https://man7.org/linux/man-pages/man8/tc-netem.8.html) di `tc-netem(8)`.

## Conclusioni e pulizia

Siamo arrivati ad avere una rete simulata in cui possiamo controllare la perdita di pacchetti e il ritardo / jitter; possiamo fare qualsiasi esperimento necessario eseguendo i nostri servizi nel namespace corretto. 

Al termine, se non abbiamo altri namespace definiti, è semplicissimo rimuovere ogni traccia dal nostro sistema con un singolo comando:

```bash
$ ip --all netns del
```
