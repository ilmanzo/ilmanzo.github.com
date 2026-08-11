---
layout: post
title: "Quanto codice stai testando ? (5)"
description: "Tracciare le librerie caricate via dlopen() on-the-fly con eBPF JIT uprobes event-driven"
categories: [programmazione, testing]
tags: [testing, linux, coverage, ebpf, bpf, uprobe, tracing, go, golang, qa, dlopen, nginx, openssl]
series: ["How much code are you testing?"]
series_order: 5
author: Andrea Manzini
date: 2026-08-11
---

## 🧭 [Dove eravamo rimasti](https://www.youtube.com/watch?v=pAgnJDJN4VA)

Bentornati a questa nuova tappa del nostro viaggio nella misurazione della test coverage sui binari precompilati!

Nel [quarto capitolo](https://ilmanzo.github.io/post/measuring-test-coverage-with-ebpf/) abbiamo introdotto **[funkoverage](https://github.com/ilmanzo/BinaryCoverage/)**, uno strumento nativo ad alte prestazioni basato su eBPF, che sfrutta `uprobe_multi` per catturare l'ingresso nelle funzioni in GNU/Linux con un overhead inferiore al 2%. Fino ad ora, le librerie statiche venivano scoperte all'installazione analizzando i binari con `ldd` (tramite le dipendenze `DT_NEEDED`).

Tuttavia, c'era un enorme elefante nella stanza: **`dlopen()`**.

Alcuni dei software più complessi e modulari al mondo, come i web server con moduli dinamici, le applicazioni enterprise basate su plugin e i database multi-protocollo, caricano le proprie dipendenze *a runtime*, al volo. Poiché queste librerie non sono dichiarate nell'header ELF `DT_NEEDED`, risultano invisibili a `ldd` durante l'installazione.

Oggi diamo la caccia a questo fuggiasco tecnologico: scopriremo come lo abbiamo risolto con una strategia elegante ed estremamente scalabile, la strumentazione eBPF JIT event-driven, e la metteremo alla prova sul campo con binari di produzione reali e non modificati come **Nginx** e **OpenSSL**!

<!--more-->

![plug](/img/pexels-realtoughcandy-11034131.jpg)
*(Immagine cortesia di https://www.pexels.com/@realtoughcandy/)*

## 🧮 [Polling attivo o JIT event-driven?](https://www.youtube.com/watch?v=bWXazVhlyxQ)

Come risolviamo questa situazione?

Un approccio ingenuo sarebbe eseguire un loop nello shim Go che controlla periodicamente `/proc/<pid>/maps` (ad esempio ogni 10ms) per rilevare nuove librerie caricate.
Tuttavia, **il polling non scala**.

In uno scenario aziendale con **5000 binari strumentati** installati, un polling attivo richiederebbe la lettura di `/proc/<pid>/maps` circa **500.000 volte al secondo**. Questo causerebbe un degrado massiccio della cache della CPU, elevata latenza I/O e strozzamento dei processi.

Per mantenere il tool leggero ed efficiente a livello enterprise, abbiamo sviluppato una strategia **JIT event-driven**:

1. **Uretprobe su `dlopen`**: All'avvio, `funkoverage` controlla una breve lista di percorsi glibc standard cercando quello che esporta davvero il simbolo `dlopen` (percorso veloce), ricadendo su una scansione una tantum di `/proc/<pid>/maps` se nessuno corrisponde. Aggancia quindi lì una return uprobe (`uretprobe`).
2. **Token speciale**: Quando la chiamata a `dlopen` nel processo target si conclude con successo, il programma eBPF intercetta il ritorno e scrive un token riservato (`0xFFFFFFFF`) nel ringbuffer `events`.
3. **Lettura event-driven**: Lo shim Go riceve il token `0xFFFFFFFF` nel suo loop in background. Solo a questo punto scandisce `/proc/<pid>/maps` per rilevare nuovi file `.so` mappati in memoria, ma lo fa per *ogni* pid attualmente presente nella mappa `watched` lato kernel, non solo per il processo radice. Quella mappa è ciò che rende possibile il tracciamento multi-processo: un tracepoint `sched_process_fork` copia il bit "watched" di un processo sui suoi figli non appena nascono, così anche un worker forkato che chiama `dlopen()` per conto proprio viene intercettato.
4. **Aggancio JIT**: Lo shim analizza i simboli ELF del plugin on-the-fly, applica le regole di inclusione/esclusione e aggancia dinamicamente le nuove uprobe con un'unica chiamata di sistema `UprobeMulti`.

Questo garantisce un consumo in stato stazionario pari allo **0% CPU** e **0% I/O**!

## 🕳️ [Il fantasma del caricamento dinamico](https://www.youtube.com/watch?v=VqoyKzgkqR4)

Quando un programma carica una libreria condivisa a runtime, utilizza le funzioni POSIX standard `dlopen()` o `dlmopen()`:

```c
void *handle = dlopen("./libplugin.so", RTLD_NOW);
```

Ecco un esempio minimo e completo. Carichiamo `libm.so.6` a runtime, risolve `sqrt` per nome, la chiama, e poi la scarica:

```c
#include <dlfcn.h>
#include <stdio.h>

int main(void) {
    void *handle = dlopen("libm.so.6", RTLD_NOW);
    if (!handle) { fprintf(stderr, "%s\n", dlerror()); return 1; }

    double (*sqrt_fn)(double) = dlsym(handle, "sqrt");
    if (!sqrt_fn) { fprintf(stderr, "%s\n", dlerror()); return 1; }

    printf("sqrt(2) = %f\n", sqrt_fn(2.0));

    dlclose(handle);
    return 0;
}
```

Si compila con `gcc example.c -ldl -o example` (`-ldl` potrebbe non servire sulle glibc moderne, ma conviene tenerlo per portabilità). Eseguendo `ldd example` vediamo solo `libc.so.6`: `libm.so.6` non è ancora mappata a quel punto, quindi resta invisibile finché `dlopen()` non viene davvero eseguita. Vale lo stesso su scala più grande: `ldd` su un binario di distribuzione come `nginx` mostra solo le dipendenze dinamiche principali, lasciandoci completamente ignari dei moduli o dei provider caricati a runtime, come `legacy.so` di OpenSSL. Non appena l'applicazione esegue codice caricato dinamicamente, la nostra mappa di copertura diventa meno efficace.

Tracciando `example` con `funkoverage`, ecco come si comporta il log di copertura prima e dopo la chiamata a `dlopen()`:

- **Prima**: all'installazione, `funkoverage` aggancia `uprobe_multi` solo su `main` e sulle funzioni della libc viste da `ldd`. Non c'è alcun indirizzo da agganciare per `sqrt`, finché `libm.so.6` non è mappata.
- **Alla chiamata di `dlopen()`**: la `uretprobe` su `dlopen` scatta nel momento in cui questa restituisce un handle non nullo, inviando il token `0xFFFFFFFF` nel ringbuffer *prima ancora* che `example` arrivi alla riga con `dlsym()`.
- **Dopo**: il loop in background dello shim Go si sveglia, confronta `/proc/<pid>/maps`, trova `libm.so.6` appena mappata, ne analizza la tabella dei simboli e aggancia via JIT una uprobe su `sqrt`, il tutto prima che venga eseguito `sqrt_fn(2.0)`. Quindi la primissima chiamata a `sqrt` in questo esempio viene già catturata:

```bash
CALLED /path/to/example main
CALLED /lib/x86_64-linux-gnu/libm.so.6 sqrt
```

Senza l'aggancio JIT, quella seconda riga non comparirebbe mai: `sqrt` girerebbe invisibile e il report di copertura sottostimerebbe silenziosamente il risultato.

---

### Il codice, per chi vuole vederlo

Lato eBPF si tratta di una singola `uretprobe` su `dlopen`, che legge il valore di ritorno direttamente dal registro di ritorno dell'architettura:

```c
SEC("uretprobe/dlopen")
int trace_dlopen_return(struct pt_regs *ctx)
{
    __u32 tgid = bpf_get_current_pid_tgid() >> 32;
    if (!bpf_map_lookup_elem(&watched, &tgid))
        return 0;

#if defined(__x86_64__)
    void *handle = (void *)ctx->ax;
#elif defined(__aarch64__)
    void *handle = (void *)ctx->regs[0];
#endif
    if (!handle)
        return 0;

    struct event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e)
        return 0;
    e->func_idx = 0xFFFFFFFF; // token riservato: "una libreria è appena stata caricata con dlopen"
    bpf_ringbuf_submit(e, 0);
    return 0;
}
```

Lato Go, `Tracer.Start` individua la libc/libdl giusta e vi si aggancia con la stessa identica API `link.OpenExecutable` + `Uretprobe` che `cilium/ebpf` ci offre già per le normali uprobe di funzione:

```go
libcPath, err := findLibcPath(rootPID)
if err == nil {
    if ex, err := link.OpenExecutable(libcPath); err == nil {
        if l, err := ex.Uretprobe("dlopen", t.objs.TraceDlopenReturn, nil); err == nil {
            t.addLink(l)
        }
    }
}
```

E lato consumer, il loop di lettura del ringbuffer si limita a gestire come caso speciale il token riservato:

```go
idx := binary.LittleEndian.Uint32(record.RawSample[:4])
if idx == 0xFFFFFFFF {
    t.handleDynamicLoad() // scandisce i pid watched, confronta /proc/*/maps, aggancia le nuove librerie via JIT
    continue
}
```

`handleDynamicLoad` è dove avviene il vero lavoro JIT: confronta la mappa di memoria di ogni processo osservato con ciò che è già strumentato, legge la tabella dei simboli ELF della nuova libreria, la fa passare per gli stessi filtri `--include`/`--exclude` usati all'installazione, e aggancia un nuovo batch di `UprobeMulti`, il tutto senza che il processo target se ne accorga mai.

---

## 🩺 [Superare gli ostacoli del mondo reale](https://www.youtube.com/watch?v=btPJPFnesV4)

Applicare questo design a binari di produzione reali come `nginx` e `openssl` ci ha messo di fronte ad alcune sfide tecniche non indifferenti. Ecco come le abbiamo risolte:

### A. Il bug del bit di esecuzione in `cilium/ebpf`
Molte librerie di sistema (come `/usr/lib/x86_64-linux-gnu/ossl-modules/legacy.so` o `libcrypto.so.3`) vengono distribuite senza il bit di esecuzione abilitato sul file system (permessi `0644`).
Nella versione `v0.21.0` di `github.com/cilium/ebpf`, il costruttore `link.OpenExecutable` verificava rigidamente la presenza di questo bit e lanciava l'errore `file is not executable`, bloccando l'aggancio delle uprobe.
* **La soluzione**: Abbiamo aggiornato `github.com/cilium/ebpf` alla versione `v0.22.0`, in cui questo controllo sui permessi di esecuzione è stato rimosso, consentendo l'aggancio delle uprobe su qualsiasi libreria condivisa su disco.

### B. Fallback resilienti per simboli e DWARF
I binari distribuiti sulle principali distro Linux sono completamente "stripped" (privi di tabella dei simboli `.symtab` e di informazioni DWARF). Per evitare crash di enumerazione:
* **La soluzione**: Abbiamo aggiornato il parser di simboli per ignorare graziosamente gli errori di decodifica DWARF e ricadere automaticamente sulla scansione dei simboli dinamici (`.dynsym`), sempre presenti per le librerie caricate a runtime!

### C. Silenzio totale e trasparente per la CI/CD
Per sostituire `/usr/sbin/nginx` in modo trasparente, il wrapper deve comportarsi **in modo identico** all'originale. Qualsiasi messaggio di diagnostica stampato dallo shim Go su `stdout` o `stderr` corromperebbe gli script di automazione o CI.
* **La soluzione**: Abbiamo introdotto una modalità silenziosa, subordinando tutti i log di diagnostica JIT alla variabile d'ambiente `FUNKOVERAGE_DEBUG`. Nel funzionamento normale, lo shim produce **esattamente 0 byte extra di output** su `stdout` o `stderr`!

### D. `CAP_SYS_RESOURCE` sui kernel moderni
Sui kernel ≥ 6.6 con contabilità della memoria BPF basata su memcg (lo standard sulle distro attuali), `rlimit.RemoveMemlock()` di `cilium/ebpf` dovrebbe essere un no-op: il kernel fa già la propria contabilità e non serve alzare `RLIMIT_MEMLOCK`. Ma la sua stessa sonda per capire "questo kernel supporta la contabilità memcg?" può fallire sotto pressione di memoria BPF e ricadere sul vecchio percorso `RLIMIT_MEMLOCK`, che richiede `CAP_SYS_RESOURCE`. Senza quella capability, lo shim falliva ancora prima di eseguire il binario reale (`remove memlock: operation not permitted`).
* **La soluzione**: Concediamo `CAP_SYS_RESOURCE` al binario shim insieme alle capability che già gli servivano, così quel percorso di fallback, raro ma reale, non si porta più dietro l'intero tracer.

---

## 🏆 [Test sul campo con Nginx](https://www.youtube.com/watch?v=qVHyl0P_P-M)

Abbiamo installato il pacchetto standard di `nginx`, sostituito in modo permanente il binario `/usr/sbin/nginx` con lo shim strumentato ed eseguito un test di configurazione:

```bash
$ sudo ./funkoverage install /usr/sbin/nginx
Installed shim for /usr/sbin/nginx (original at /var/coverage/bin/nginx)

$ sudo /usr/sbin/nginx -t
2026/07/28 20:38:30 [emerg] 47221#47221: open() "/etc/letsencrypt/options-ssl-nginx.conf" failed (2: No such file or directory) in /etc/nginx/sites-enabled/example.duckdns.org:90
nginx: configuration file /etc/nginx/nginx.conf test failed
```

Nessun messaggio di debug, nessun log dinamico nel terminale: silenzio perfetto! Eppure, sotto il cofano, eBPF ha intercettato il caricamento di `libcrypto.so.3` e `libssl.so.3`, strumentato **oltre 6.400 funzioni dinamiche** on-the-fly, scrivendo questo pulitissimo log di copertura:

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

## 🩹 Round due: irrobustire dopo uno sguardo più attento

Un prototipo che funziona una volta sulla propria macchina e una feature di cui ci si può fidare in produzione sono due cose diverse. Abbiamo sottoposto il percorso JIT di dlopen a una code review indipendente: un run di `go test -race` ha scovato un bug vero in pochi minuti:

- **Una race condition allo shutdown.** Il gestore di dlopen gira su una goroutine in background, aggiungendo i link delle librerie appena scoperte a uno slice condiviso, mentre `Stop()` chiudeva e svuotava concorrentemente lo *stesso* slice dalla goroutine chiamante durante lo spegnimento: un accesso concorrente non sincronizzato, esattamente il tipo di bug che si manifesta solo sotto carico, nel momento peggiore possibile. Risolto con un piccolo mutex attorno allo stato condiviso.
- **I filtri ignoravano silenziosamente le librerie dinamiche.** I filtri regex `--include`/`--exclude` funzionavano correttamente sulle funzioni enumerate staticamente, ma qualsiasi cosa scoperta in seguito via `dlopen` li bypassava del tutto. Ora serializziamo i pattern del filtro compilato in un piccolo sidecar `.filter.json` al momento dell'installazione, e lo shim riapplica esattamente la stessa logica a tutto ciò che scopre a runtime.
- **Un limite di capacità senza alcun allarme.** La mappa di deduplica lato kernel viene dimensionata una sola volta, al caricamento del programma BPF, con un margine riservato alle funzioni scoperte in seguito. Superato quel margine, le lookup dei cookie restituiscono silenziosamente `NULL` nel kernel: la chiamata viene semplicemente scartata, senza che nulla venga registrato da nessuna parte. Per uno strumento di coverage, un falso negativo silenzioso è quasi il peggior modo di fallire. Ora invece taglia e avvisa ad alta voce.
- **Un `bpf_printk` di debug che avevamo dimenticato di rimuovere.** Le uprobe si agganciano per file e offset, a livello di intero sistema, non per processo. Due stampe di debug nella uretprobe di dlopen scattavano per *ogni* chiamata a `dlopen()` sull'intera macchina, non solo per quella che ci interessava, lavorando silenziosamente contro la promessa di "0% overhead su scala" della Parte 4. Ora sono sparite.
- **Supporto per glibc più datate.** `dlopen` è approdata in `libc.so.6` solo con glibc 2.34 (2021): prima viveva in `libdl.so.2`. La logica di aggancio della uretprobe ora verifica che il simbolo sia effettivamente presente in una libreria candidata prima di impegnarsi su di essa, invece di limitarsi a controllare che il file esista su disco.

Altri due bug sono emersi scrivendo test, non leggendo codice: è esattamente il senso di scriverli.

- `isSystemLib()`, l'euristica che salta le librerie di sistema note per mantenere le tracce dinamiche snelle, aveva una regex in cui l'alternativa per `libstdc++` non poteva *mai* effettivamente corrispondere: un ancoraggio di confine di parola `\b` subito dopo un carattere `+` non può scattare, dato che `+` non è un carattere di parola. `libstdc++.so.6` veniva silenziosamente strumentata per intero invece di essere saltata, ogni singola volta.
- Il lettore di simboli ELF per le librerie caricate dinamicamente ricadeva su `.dynsym` solo se la lettura di `.symtab` falliva del tutto: la `libc.so.6` di glibc distribuisce però una `.symtab` che ha successo pur omettendo funzioni esportate come `dlopen` stessa, presenti solo in `.dynsym`. Soluzione: unire entrambe le tabelle invece di sceglierne una.

---

## 🏁 [Conclusione](https://www.youtube.com/watch?v=8fPf6L0XNvM)

Grazie a questa architettura JIT event-driven, `funkoverage` estende il proprio tracciamento basato su uprobe anche alle librerie caricate a runtime via `dlopen()`, in aggiunta alle dipendenze enumerate staticamente della Parte 4: Go puro ed eBPF, nativo sia su x86_64 sia su ARM64.

Al momento di questo post il progetto è alla versione **v0.8.0**. Prossimi passi, dalla roadmap del progetto stesso: eliminare l'ultimo fork-exec di `ldd` a favore del parsing diretto di `DT_NEEDED` via `debug/elf`, e una guardia che rifiuti di fare `install` sopra un binario già shimmato.

Il progetto è ospitato su [github.com/ilmanzo/BinaryCoverage](https://github.com/ilmanzo/BinaryCoverage): segnalazioni, commenti e pull request sono i benvenuti!

Sentitevi liberi di lasciare commenti o feedback, happy hacking! :wave:

![eBPF logo](/img/ebpf_logo.png)
