---
layout: post
title: "installare e configurare VRRP su linux"
description: ""
category: 
tags: [linux, networking, HA]
---
{% include JB/setup %}

cos'è VRRP ? E' un protocollo basato su multicast che permette a due o più server di esporre un indirizzo virtuale condiviso, in modo che il servizio che sta girando sulle due macchine distinte venga visto dal client come un unico server in alta affidabilità. Disattivando uno dei due "nodi" il servizio viene erogato dal nodo rimanente, in maniera trasparente per il client che si connette all'indirizzo "virtuale".

L'implementazione Linux è completamente userspace e aderisce alle specifiche della RFC2338, ed è talmente semplice da usare che non necessita nemmeno di un file di configurazione. Installato il pacchetto, supponiamo di voler fornire un servizio ridondato utilizzando due server, rispettivamente 

A con indirizzo 192.168.1.11 (eth0)
B con indirizzo 192.168.1.12 (eth0)

tutti i client si connetteranno all'indirizzo 192.168.1.10 che sarà "gestito" in alta affidabilità da VRRPD:

testeremo la connettività con il client C:

andrea@client:~$ ping 192.168.1.11
PING 192.168.1.11 (192.168.1.11) 56(84) bytes of data.
64 bytes from 192.168.1.11: icmp_req=1 ttl=63 time=0.882 ms
64 bytes from 192.168.1.11: icmp_req=2 ttl=63 time=0.835 ms
64 bytes from 192.168.1.11: icmp_req=3 ttl=63 time=1.03 ms
64 bytes from 192.168.1.11: icmp_req=4 ttl=63 time=1.01 ms

andrea@client:~$ ping 192.168.1.12
PING 192.168.1.12 (192.168.1.12) 56(84) bytes of data.
64 bytes from 192.168.1.12: icmp_req=1 ttl=63 time=0.483 ms
64 bytes from 192.168.1.12: icmp_req=2 ttl=63 time=0.255 ms
64 bytes from 192.168.1.12: icmp_req=3 ttl=63 time=0.512 ms
64 bytes from 192.168.1.12: icmp_req=4 ttl=63 time=0.518 ms


ora facciamo partire vrrpd sui due server:

andrea@serverA:~$ sudo vrrpd -v 11






