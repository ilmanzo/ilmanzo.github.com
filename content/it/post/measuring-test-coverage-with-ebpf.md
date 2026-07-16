---
layout: post
title: "Quanto codice stai testando? (4)"
description: "Copertura nativa dei binari con eBPF grazie a funkoverage. Nessun SDK, nessuna ricompilazione, qualsiasi architettura"
categories: [programmazione, testing]
tags: [testing, linux, copertura, ebpf, bpf, uprobe, tracciamento, go, golang, qa]
series: ["How much code are you testing?"]
series_order: 4
author: Andrea Manzini
date: 2026-05-13
---

## 🧭 [Dove eravamo rimasti](https://www.youtube.com/watch?v=uB1D9wWxd2w)

Benvenuti al nuovo capitolo della nostra serie dedicata alla misurazione della copertura dei test per i programmi binari!

Nella [parte 1](https://ilmanzo.github.io/it/post/measuring-coverage-of-integration-tests/) abbiamo utilizzato il flag `-cover` integrato in Go: pulito e preciso, ma funziona solo se si possiede il codice sorgente e lo si può ricompilare. Nella [parte 2](https://ilmanzo.github.io/it/post/measuring-test-coverage-on-binaries/) abbiamo usato `valgrind` e `gdb` per tracciare `gzip` senza toccarne il sorgente. Nella [parte 3](https://ilmanzo.github.io/it/post/pintool-function-tracing/) abbiamo esplorato Intel PIN, un vero e proprio framework di strumentazione binaria dinamica: potente, ma dotato di un SDK C++ proprietario da circa 100 MB e limitato a x86_64.

Alla fine di quel post avevo promesso che saremmo andati oltre: *automazione completa, qualsiasi binario, nessuna ricompilazione*. Oggi manteniamo quella promessa con un approccio eBPF nativo, e il risultato è uno strumento chiamato **funkoverage**.

![probe](/img/pexels-tanfeez-10699357.jpg)
(immagine per gentile concessione di https://www.pexels.com/@tanfeez/)

## 🕳️ [Perché l'eBPF cambia tutto](https://www.youtube.com/watch?v=7W3yz6abJkU)

[eBPF](https://ebpf.io/) è una tecnologia del kernel Linux che permette di eseguire piccoli programmi sandbox *all'interno del kernel* in risposta a eventi, senza caricare moduli del kernel o applicare patch al kernel stesso. Ai fini del tracciamento, ciò significa che possiamo agganciare i punti di ingresso delle funzioni con gli **uprobes** e ricevere notifiche nello spazio utente tramite un ring buffer, il tutto con un sovraccarico (overhead) trascurabile.

Due funzionalità di eBPF rendono questo approccio particolarmente interessante per la misurazione della copertura:

**`uprobe_multi`** (disponibile a partire da Linux 6.6) consente di collegare uprobes per un intero binario o libreria in una *singola chiamata di sistema (syscall)*, passando tutti i nomi dei simboli e i "cookie" contemporaneamente. In precedenza era necessaria una syscall per ogni funzione; con 8.000 funzioni, si trattava di 8.000 syscall solo per la configurazione. Ora ne basta una.

**Deduplicazione della prima chiamata lato kernel**: all'interno del programma BPF, utilizziamo un'operazione atomica compare-and-swap su un flag per ciascuna funzione, memorizzato in una mappa del kernel. Ciò significa che ogni funzione attiva esattamente un evento verso lo spazio utente, indipendentemente da quante volte viene chiamata durante il ciclo di vita del programma. Ai fini della copertura, questo è esattamente ciò che vogliamo: un segnale pulito sì/no senza rumore.

Ecco un confronto tra i diversi approcci:

| Approccio | Overhead | SDK richiesto | Architettura | Deduplicazione prima chiamata |
|---|---|---|---|---|
| valgrind/callgrind | ~10–20 volte più lento | Nessuno | x86_64 | No |
| Intel PIN | ~5–10 volte più lento | ~100MB C++ SDK | x86_64 | No |
| **eBPF uprobe_multi** | **~1–2% overhead** | **Nessuno** | **QUALSIASI** | **Sì** |

La differenza in termini di overhead è enorme nella pratica. Con valgrind, anche un banale `gzip -h` richiede mezzo secondo. Con gli uprobes, sono necessari pochi millisecondi: il programma gira a velocità essenzialmente nativa.

## 🥷 [Un impostore trasparente](https://www.youtube.com/watch?v=sfCLt0kTd5E)

[funkoverage](https://github.com/ilmanzo/BinaryCoverage) è uno strumento scritto in Go puro che sfrutta questa infrastruttura eBPF per fornire una copertura a livello di funzione su qualsiasi binario ELF, senza bisogno del codice sorgente o di ricompilazione.

Il design si basa su due binari che lavorano in sinergia:

| Componente | Descrizione |
|---|---|
| `funkoverage` | Interfaccia a riga di comando (configurazione/installazione/report) |
| `funkoverage-shim` | Sostituto trasparente |

**`funkoverage`** è la CLI con cui si interagisce: installa e disinstalla lo shim, enumera le funzioni e genera i report di copertura.

**`funkoverage-shim`** è un "piccolo" binario Go che viene installato *al posto del* binario di destinazione. È completamente generico: non sa nulla di `gzip` o di qualsiasi altro programma. Quando viene richiamato, legge un file sidecar JSON per scoprire quali funzioni agganciare, attiva i probe BPF e quindi avvia in modo trasparente il vero binario.

L'esecuzione di `sudo funkoverage install /usr/bin/gzip` esegue questi passaggi:

1. Sposta il vero binario `gzip` in `/var/coverage/bin/gzip`
2. Enumera tutte le funzioni dalla tabella dei simboli (ricorrendo a DWARF se necessario)
3. Scrive un file sidecar `gzip.funcs.json` con l'elenco dei simboli
4. Copia il binario shim in `/usr/bin/gzip`
5. Esegue `setcap cap_bpf,cap_perfmon+ep` sullo shim in modo che possa agganciare gli uprobes senza dover essere eseguito come root

Da quel momento in poi, ogni invocazione di `gzip` passa in modo del tutto trasparente attraverso lo shim. La sequenza di runtime dello shim si presenta così:

```txt
l'utente esegue "gzip -h"
      │
      ▼
/usr/bin/gzip  ← questo ora è lo shim
      │
      ├── legge gzip.funcs.json
      ├── esegue il fork di un processo figlio (in pausa su una pipe)
      ├── carica il programma BPF incorporato
      ├── link.UprobeMulti(tutti i simboli)   ← una sola syscall per immagine
      ├── inizializza la mappa del kernel "watched" con il PID del figlio
      ├── avvia la goroutine di lettura del ring buffer
      │
      ├── sblocca il figlio tramite la pipe → il figlio esegue exec() del vero gzip
      │
      ├── BPF si attiva alla prima chiamata di ciascuna funzione
      │       └── evento → ring buffer → demangling → _called.log
      │
      └── il figlio termina → rimuove i probe → svuota il buffer → chiude il log
```

Nessun `LD_PRELOAD`, nessun `ptrace`, nessuna modifica al binario. Il vero binario viene eseguito non modificato all'interno del processo figlio; lo shim genitore si limita a osservare ciò che accade a livello di kernel.

## 🩺 [Agganciare gzip, dal vivo](https://www.youtube.com/watch?v=jEjVD3fqTkk)

Useremo di nuovo `gzip` — lo stesso bersaglio della parte 2 — in modo da poter confrontare direttamente i numeri.

Compilate e installate funkoverage (avrete bisogno di Go 1.26+ e di un kernel Linux ≥ 6.6 con BTF abilitato):

```bash
$ git clone https://github.com/ilmanzo/BinaryCoverage
$ cd BinaryCoverage
$ ./build.sh
$ sudo cp funkoverage funkoverage-shim /usr/local/bin/
```

Ora installate lo shim su gzip:

```bash
$ sudo funkoverage install /usr/bin/gzip
✓ moved /usr/bin/gzip → /var/coverage/bin/gzip
✓ enumerated 80 functions
✓ shim installed at /usr/bin/gzip (cap_bpf,cap_perfmon+ep)
```

Eseguiamo il nostro semplice smoke test dalla parte 2:

```bash
$ gzip -h
Usage: gzip [OPTION]... [FILE]...
Compress or uncompress FILEs (by default, compress FILES in-place).
...
```

L'output è identico: `gzip` si comporta esattamente come prima. Ma ora abbiamo un file di log:

```bash
$ tail -5 /var/coverage/data/gzip_*_called.log
CALLED /var/coverage/bin/gzip main
CALLED /var/coverage/bin/gzip try_help
CALLED /var/coverage/bin/gzip license
CALLED /var/coverage/bin/gzip rpl_printf
CALLED /var/coverage/bin/gzip progerror
```

Generiamo il report di copertura:

```bash
$ funkoverage report /var/coverage/data /tmp/report
$ cat /tmp/report/gzip.txt
Functions: 9/80 (11.25%)
```

**11.25%** — esattamente quanto riportato da valgrind nella parte 2. Rassicurante! Ma questa volta `gzip -h` è stato eseguito in pochi millisecondi, non in mezzo secondo.

## 🌒 [A caccia delle funzioni oscure](https://www.youtube.com/watch?v=8WEtxJ4-sh4)

Lo shim accoda i dati al file di log a ogni esecuzione e il report si accumula. Seguiamo lo stesso percorso della parte 2 e osserviamo crescere la copertura.

Verifichiamo la versione:

```bash
$ gzip -V
$ funkoverage report /var/coverage/data /tmp/report
Functions: 10/80 (12.50%)
```

Proviamo un percorso di errore, ad esempio un file inesistente:

```bash
$ gzip foobar
gzip: foobar: No such file or directory
$ funkoverage report /var/coverage/data /tmp/report
Functions: 19/80 (23.75%)
```

C'è stato un bel balzo: il codice di gestione degli errori ha attivato funzioni che non avevamo ancora toccato. Ora proviamo ad effettuare una compressione reale:

```bash
$ echo "hello funkoverage" > /tmp/test.txt
$ gzip /tmp/test.txt
$ gzip -d /tmp/test.txt.gz
$ funkoverage report /var/coverage/data /tmp/report
Functions: 52/80 (65.00%)
```

🎉 Stesso percorso di valgrind: 11% → 23% → 65%. Il report HTML mostra anche le funzioni *non chiamate* per nome, il che è comodissimo per sapere esattamente dove la suite di test presenti ancora delle lacune.

## 🌍 [Un solo binario, qualsiasi chip](https://www.youtube.com/watch?v=K0HSD_i2DvA)

Quando abbiamo esteso funkoverage per supportare ARM64, non abbiamo dovuto modificare minimamente la logica del programma BPF: il set di istruzioni eBPF è indipendente dall'architettura. Ciò di cui avevamo bisogno era compilare il codice BPF in C per ciascuna architettura di destinazione e includere entrambi gli oggetti nella repository.

Lo strumento `bpf2go` del progetto cilium/ebpf genera un file Go per ciascuna architettura, e il meccanismo dei tag di compilazione di Go seleziona quello corretto in fase di build:

```
tracer_x86_bpfel.go   → //go:build 386 || amd64
tracer_arm64_bpfel.go → //go:build arm64
```

Gli oggetti pre-generati sono inclusi nella repository, quindi per una compilazione standard è necessario solo Go — non servono Clang o gli header del kernel. Su una macchina ARM64 (un Raspberry Pi, un'istanza cloud Graviton o una VM Apple Silicon), si applicano esattamente la stessa CLI e lo stesso flusso di lavoro.

## 🏁 [La copertura che vi spettava](https://www.youtube.com/watch?v=xk8mm1Qmt-Y)

Abbiamo fatta molta strada dal semplice `go build -cover` del primo capitolo. Con eBPF e `uprobe_multi` ora disponiamo di uno strumento che:

- Funziona su *qualsiasi* binario ELF — strumenti di terze parti, pacchetti di distribuzione, demoni — senza bisogno del codice sorgente o di ricompilazione
- Introduce un overhead di runtime trascurabile, rendendolo pratico anche per le suite di test più lunghe
- Produce dati di copertura puliti, relativi solo alla prima chiamata, senza bisogno di script di collaudo o parsing manuale dei log
- Funziona sia su x86_64 che su ARM64 senza alcuna modifica al flusso di lavoro

Se state scrivendo test di integrazione per un binario di cui non controllate i sorgenti, funkoverage vi offre finalmente quel ciclo di feedback sulla copertura che vi mancava.

Trovate il progetto su [github.com/ilmanzo/BinaryCoverage](https://github.com/ilmanzo/BinaryCoverage) — segnalazioni di bug e pull request sono le benvenute.

Se questo approccio vi incuriosisce, date un'occhiata anche a [xcover](https://github.com/maxgio92/xcover), un altro strumento di copertura basato su eBPF. È stato recentemente presentato in un lightning talk al FOSDEM 2026 ([slide](https://fosdem.org/2026/events/attachments/CNPVJL-lightning_lightning_talks_1/slides/267016/xcover_c_2wnfgpz.pdf)).

Lasciate pure i vostri commenti e feedback, buon hacking! :wave:

![eBPF logo](/img/ebpf_logo.png)