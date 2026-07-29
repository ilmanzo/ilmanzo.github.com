---
layout: post
title: "Quanto codice stai testando ? (5)"
description: "Tracciare le librerie caricate via dlopen() on-the-fly con eBPF JIT uprobes event-driven"
categories: [programmazione, testing]
tags: [testing, linux, coverage, ebpf, bpf, uprobe, tracing, go, golang, qa, dlopen, nginx, openssl]
series: ["How much code are you testing?"]
series_order: 5
author: Andrea Manzini
date: 2026-08-30
draft: true
---

## 🧭 [Where we left off](https://www.youtube.com/watch?v=uB1D9wWxd2w)

Benvenuti a questa nuova tappa del nostro viaggio nella misura della test coverage su binari pre-compilati!

Nel [quarto capitolo](https://ilmanzo.github.io/post/measuring-test-coverage-with-ebpf/) abbiamo introdotto **funkoverage**, uno strumento nativo ad alte prestazioni basato su eBPF, che sfrutta `uprobe_multi` per catturare l'ingresso nelle funzioni in GNU/Linux con un overhead inferiore al 2%. Fino ad ora, le librerie statiche venivano scoperte all'installazione analizzando i binari con `ldd` (tramite le dipendenze `DT_NEEDED`).

Tuttavia, c'era un enorme elefante nella stanza: **`dlopen()`**.

Alcuni dei software più complessi e modulari del mondo — come web server con moduli dinamici, applicazioni enterprise basate su plugin e database multi-protocollo — caricano le proprie dipendenze *a runtime* on-the-fly. Poiché queste librerie non sono dichiarate negli header ELF (`DT_NEEDED`), sono invisibili a `ldd` durante l'installazione.

Oggi daremo la caccia a questo fuggiasco tecnologico, vedremo come abbiamo risolto il problema con una strategia elegante ed estremamente scalabile: l'instrumentazione eBPF JIT event-driven, e la testeremo sul campo con binari di produzione reali e non modificati come **Nginx** e **OpenSSL**!

<!--more-->

![plug](/img/pexels-realtoughcandy-11034131.jpg)
*(Immagine cortesia di https://www.pexels.com/@realtoughcandy/)*

## 🕳️ [The Dynamic Loading Ghost](https://www.youtube.com/watch?v=7W3yz6abJkU)

Quando un programma carica una libreria condivisa a runtime, utilizza le funzioni POSIX standard `dlopen()` o `dlmopen()`:

```c
void *handle = dlopen("./libplugin.so", RTLD_NOW);
```

Poiché questa libreria non viene mappata all'avvio del processo, gli strumenti di analisi statici come `ldd` sono completamente ciechi.

Se eseguiamo `ldd` su un binario standard di distribuzione come `nginx`, vediamo solo le sue dipendenze dinamiche principali, rimanendo completamente ciechi ai moduli o provider caricati a runtime (come `legacy.so` di OpenSSL). Questo significa che non appena l'applicazione salta a eseguire codice caricato dinamicamente, la nostra mappa di copertura scompare nel buio.

---

## 🧮 [Active Polling vs. Event-Driven JIT](https://www.youtube.com/watch?v=sfCLt0kTd5E)

Come risolviamo questa situazione?

Un approccio ingenuo sarebbe eseguire un loop nello shim Go che controlla periodicamente `/proc/<pid>/maps` (ad esempio ogni 10ms) per rilevare nuove librerie caricate.
Tuttavia, **il polling non scala**.

In uno scenario aziendale con **5000 binari instrumentati** installati, un polling attivo richiederebbe la lettura di `/proc/<pid>/maps` circa **500.000 volte al secondo**. Questo causerebbe un degrado massiccio della cache della CPU, elevata latenza I/O e strozzamento dei processi.

Per mantenere il tool leggero ed efficiente a livello enterprise, abbiamo sviluppato una strategia **JIT event-driven**:

1. **Uretprobe su `dlopen`**: All'avvio, `funkoverage` analizza `/proc/<pid>/maps` una sola volta per individuare il percorso di `libc.so.6` o `libdl.so.2` caricato nel processo. Viene quindi agganciata una return uprobe (`uretprobe`) al simbolo di `dlopen`.
2. **Token Speciale**: Quando la chiamata a `dlopen` nel processo target si conclude con successo, il programma eBPF intercetta il ritorno e scrive un token riservato (`0xFFFFFFFF`) nel ringbuffer `events`.
3. **Lettura Event-Driven**: Lo shim Go riceve il token `0xFFFFFFFF` nel suo loop in background. Solo a questo punto legge `/proc/<pid>/maps` per rilevare nuovi file `.so` mappati in memoria.
4. **JIT Attachment**: Lo shim analizza i simboli ELF del plugin on-the-fly, applica le regole di inclusione/esclusione e aggancia dinamicamente le nuove uprobe con un'unica chiamata di sistema `UprobeMulti`.

Questo garantisce un consumo in stato stazionario pari allo **0% CPU** e **0% I/O**!

---

## 🩺 [Superare gli Ostacoli del Mondo Reale](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

Applicare questo design a binari di produzione reali come `nginx` e `openssl` ci ha messo di fronte ad alcune sfide tecniche non indifferenti. Ecco come le abbiamo risolte:

### A. Il Bug del Bit di Esecuzione in `cilium/ebpf`
Molte librerie di sistema (come `/usr/lib/x86_64-linux-gnu/ossl-modules/legacy.so` o `libcrypto.so.3`) vengono distribuite senza il bit di esecuzione abilitato sul file system (permessi `0644`).
Nella versione `v0.21.0` di `github.com/cilium/ebpf`, il costruttore `link.OpenExecutable` verificava rigidamente la presenza di questo bit e lanciava l'errore `file is not executable`, bloccando l'aggancio delle uprobe.
* **La Soluzione**: Abbiamo aggiornato `github.com/cilium/ebpf` alla versione `v0.22.0`, in cui questo controllo sui permessi di esecuzione è stato rimosso, consentendo l'aggancio delle uprobe su qualsiasi libreria condivisa su disco.

### B. Fallback Resilienti per Simboli e DWARF
I binari distribuiti sulle principali distro Linux sono completamente "stripped" (privi di tabella dei simboli `.symtab` e di informazioni DWARF). Per evitare crash di enumerazione:
* **La Soluzione**: Abbiamo aggiornato il parser di simboli per ignorare graziosamente gli errori di decodifica DWARF e ricadere in modo automatico sulla scansione dei simboli dinamici (`.dynsym`), che sono garantiti essere sempre presenti per le librerie caricate a runtime!

### C. Silenzio Totale e Trasparente per la CI/CD
Per sostituire `/usr/sbin/nginx` in modo trasparente, il wrapper deve comportarsi **in modo identico** all'originale. Qualsiasi messaggio di diagnostica stampato dallo shim Go su `stdout` o `stderr` corromperebbe gli script di automazione o CI.
* **La Soluzione**: Abbiamo introdotto una modalità silenziosa veicolando tutti i log di diagnostica JIT dietro la variabile d'ambiente `FUNKOVERAGE_DEBUG`. Nel funzionamento normale, lo shim produce **esattamente 0 byte extra di output** su `stdout` o `stderr`!

---

## 🏆 [Test sul Campo con Nginx](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

Abbiamo installato il pacchetto standard di `nginx`, wrap-installato in modo permanente il percorso `/usr/sbin/nginx` ed eseguito un test di configurazione:

```bash
$ sudo ./funkoverage install /usr/sbin/nginx
Installed shim for /usr/sbin/nginx (original at /var/coverage/bin/nginx)

$ sudo /usr/sbin/nginx -t
2026/07/28 20:38:30 [emerg] 47221#47221: open() "/etc/letsencrypt/options-ssl-nginx.conf" failed (2: No such file or directory) in /etc/nginx/sites-enabled/manzoweb.duckdns.org:90
nginx: configuration file /etc/nginx/nginx.conf test failed
```

Nessun messaggio di debug o log dynamic nel terminale: silenzio perfetto! Eppure, sotto il cofano, eBPF ha intercettato il caricamento di `libcrypto.so.3` e `libssl.so.3`, instrumentato **oltre 6.400 funzioni dinamiche** on-the-fly, scrivendo questo pulitissimo log di copertura:

```bash
$ head -n 10 /var/coverage/data/nginx_20260728-203828_1785263908966542979_called.log
CALLED /var/coverage/bin/nginx ngx_strerror_init
CALLED /var/coverage/bin/nginx ngx_time_init
CALLED /var/coverage/bin/nginx ngx_time_update
CALLED /lib/x86_64-linux-gnu/libcrypto.so.3 OPENSSL_INIT_new
CALLED /lib/x86_64-linux-gnu/libcrypto.so.3 OPENSSL_INIT_set_config_appname
CALLED /lib/x86_64-linux-gnu/libssl.so.3 OPENSSL_init_ssl
CALLED /lib/x86_64-linux-gnu/libcrypto.so.3 OPENSSL_init_crypto
```

Il report finale ha analizzato correttamente **14.301 funzioni totali** registrando l'attivazione di **772 funzioni** su Nginx e le sue librerie crittografiche caricate a runtime!

---

## 🏁 [Conclusion](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

Grazie a questa nuova architettura JIT event-driven, `funkoverage` raggiunge una trasparenza totale:

- **100% Coverage**: Traccia le dipendenze statiche e i plugin caricati dinamicamente.
- **Enterprise-Ready**: Scala in sicurezza su **5000+ binari** senza impatto stazionario su CPU e memoria.
- **Pure-Go ed eBPF**: Funziona nativamente sia su x86_64 sia su ARM64 su kernel moderni.

Il progetto è ospitato su [github.com/ilmanzo/BinaryCoverage](https://github.com/ilmanzo/BinaryCoverage) — segnalazioni, commenti e pull request sono i benvenuti!

Sentitevi liberi di lasciare commenti o feedback, happy hacking! :wave:

![eBPF logo](/img/ebpf_logo.png)
