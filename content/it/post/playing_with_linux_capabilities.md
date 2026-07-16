---
layout: post
description: "Cosa sono e come utilizzare le capabilities del kernel Linux"
title: "Giocare con le capabilities del kernel Linux"
categories: linux
tags: [linux, tutorial, system, kernel, security, sysadmin, capabilities]
author: Andrea Manzini
date: 2024-08-02
---

## 🔐 Introduzione

Come sysadmin esperti, avrete probabilmente familiarità con il tradizionale approccio "tutto o niente": se una shell o un processo è in esecuzione con `UID==0`, può fare quasi tutto sul sistema; al contrario, un processo utente comune è limitato in vari modi: tipicamente non può aprire socket RAW, non può fare il bind di porte "privilegiate" inferiori alla 1024, non può cambiare la proprietà di un file (chown) e così via.

Le Linux capabilities sono una funzionalità, introdotta gradualmente a partire dal kernel 2.2, che permette un controllo più granulare sulle operazioni privilegiate, superando la tradizionale distinzione binaria tra root e non-root. Proprio come usando `sudo` possiamo eseguire comandi specifici come un altro utente (anche root) senza diventare permanentemente quell'utente, utilizzando le capabilities **possiamo concedere a un programma solo determinati privilegi senza doverlo eseguire come root**.

![linux-on-ice](/img/pexels-realtoughcandy-11034131.jpg)
Crediti immagine a: [@realtoughcandy](https://www.pexels.com/@realtoughcandy/)

## 🧩 Cosa sono?

L'idea è semplice: suddividere tutte le possibili chiamate privilegiate del kernel in gruppi di funzionalità correlate, in modo da poter assegnare ai processi solo il sottoinsieme di cui hanno effettivamente bisogno. Di conseguenza, le chiamate del kernel sono state suddivise in qualche dozzina di categorie diverse, con ottimo successo.

Il kernel Linux implementa una moltitudine di questi permessi microscopici. Alcune delle capabilities più comunemente utilizzate sono:

- CAP_SYS_ADMIN: Consente una vasta gamma di operazioni. Questa capability dovrebbe essere evitata a favore di capabilities più specifiche.
- CAP_CHOWN: Consente modifiche allo User ID e al Group ID dei file 
- CAP_DAC_READ_SEARCH: Consente di bypassare i controlli di lettura dei file e di lettura/esecuzione delle directory. Un programma con questa capability può essere utilizzato per leggere qualsiasi file sul sistema.
- CAP_DAC_OVERRIDE: Sovrascrive il DAC (Discretionary Access Control), ovvero bypassa i controlli dei permessi di lettura/scrittura/esecuzione. Questa capability garantisce a un eseguibile la possibilità di accedere e modificare qualsiasi file sul filesystem.
- CAP_NET_BIND_SERVICE: Consente di effettuare il bind su numeri di porta inferiori alla 1024.
- CAP_KILL: Consente di bypassare i controlli sui permessi per l'invio di segnali ai processi come SIGHUP e SIGKILL.
- CAP_SYS_NICE: Consente di modificare il valore di niceness e la priorità di scheduling dei processi, tra le altre cose.
- CAP_SYS_RESOURCE: Consente di ignorare vari limiti sulle risorse di sistema, come le quote disco, i limiti di tempo della CPU, ecc.

La funzionalità delle capabilities è stata introdotta nel kernel 2.2 nel 1999, ma inizialmente riguardava solo i processi. Nel 2008 sono state introdotte le capabilities anche per i file.
Al momento della scrittura, ci sono 40 capabilities definite e implementate; potete ottenere l'elenco completo con il comando

```bash
$ systemd-analyze capability
```

oppure nella pagina di manuale [`capabilities(7)`](https://man7.org/Linux/man-pages/man7/capabilities.7.html).   

## 🔧 Come usarle?

Parlando di userspace, esistono due diversi pacchetti per la gestione delle capabilities: `libcap` e `libcap-ng`. Quest'ultimo è progettato per essere più semplice del primo, quindi ci concentreremo su quello. 

Installiamo il pacchetto che useremo per i nostri esperimenti: 

```bash
$ sudo zypper install libpcap-ng-utils 

$ rpm -ql libcap-ng-utils 
/usr/bin/captest
/usr/bin/filecap
/usr/bin/netcap
/usr/bin/pscap
/usr/share/licenses/libcap-ng-utils
/usr/share/licenses/libcap-ng-utils/COPYING
/usr/share/man/man8/captest.8.gz
/usr/share/man/man8/filecap.8.gz
/usr/share/man/man8/netcap.8.gz
/usr/share/man/man8/pscap.8.gz
```

Il pacchetto fornisce diversi strumenti utili:

- `captest`: Verifica le capabilities del processo corrente
- `filecap`: Visualizza o modifica le capabilities dei file
- `netcap`: Mostra le capabilities di rete dei programmi esposti in rete
- `pscap`: Elenca le capabilities dei processi in esecuzione


Utilizzo di filecap:
`filecap` è utilizzato per visualizzare o modificare le capabilities dei file. Ecco come usarlo:

## 💻 Un esempio rapido

È facile avviare un semplice server HTTP in Python:

```bash
/usr/bin/python3 -m http.server   
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
^C
Keyboard interrupt received, exiting.
```

di default si avvia sulla porta 8000, perché gli utenti non privilegiati non possono fare il bind di porte inferiori:

```bash
$ /usr/bin/python3 -m http.server 80
Traceback (most recent call last):
[...]
PermissionError: [Errno 13] Permission denied
```

Possiamo concedere al binario Python la capability di effettuare il bind su porte inferiori utilizzando:

```bash
$ sudo filecap /usr/bin/python3 net_bind_service

$ /usr/bin/python3 -m http.server 80               
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
^C
Keyboard interrupt received, exiting.
```

per ripristinare lo stato precedente, possiamo usare la parola chiave `none`:

```bash
$ sudo filecap /usr/bin/python3 none

$ /usr/bin/python3 -m http.server 80
[...]          
PermissionError: [Errno 13] Permission denied
```

## ⚙️ Utilizzo di systemd

Systemd, il sistema di init utilizzato in molte moderne distribuzioni Linux, offre un supporto robusto per la gestione delle capabilities. Questa integrazione consente un controllo granulare sui privilegi dei servizi senza doverli eseguire come root.

Direttive relative alle capabilities:
I file unit di systemd supportano diverse direttive per la gestione delle capabilities:


- `CapabilityBoundingSet`: Limita le capabilities che un servizio può avere.
- `AmbientCapabilities`: Concede capabilities aggiuntive a un servizio.
- `SecureBits`: Imposta i flag dei bit di sicurezza (secure bits) per limitare ulteriormente l'uso delle capabilities.

Ecco un esempio di un file unit di servizio di systemd che concede il permesso di effettuare il bind su porte inferiori:

```
[Service]
User=bob
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

## 🔍 Uno sguardo all'interno

Nel kernel Linux, concettualmente le capabilities sono gestite in insiemi (sets), rappresentati come maschere di bit (bit masks). Per tutti i processi in esecuzione, le informazioni sulle capabilities sono mantenute per thread; per i binari nel file system, sono memorizzate negli attributi estesi (extended attributes).
Esistono cinque insiemi di capabilities: *Permitted*, *Inheritable*, *Effective*, *Bounding* e *Ambient*. Di questi, tuttavia, solo i primi tre possono essere assegnati ai file eseguibili. L'insieme *Permitted* include le capabilities assegnate a un determinato eseguibile; l'insieme *Effective* è un sottoinsieme di quello Permitted e include le capabilities effettivamente utilizzate. Infine, l'insieme *Inheritable* include le capabilities che possono essere ereditate dai processi figli. Per una spiegazione dettagliata del flusso delle capabilities, consultate [questo post di blog](https://blog.ploetzli.ch/2014/understanding-Linux-capabilities/) di Henryk Plötz o [quest'altro](https://blog.container-solutions.com/Linux-capabilities-why-they-exist-and-how-they-work) di Adrian Mouat.


Per i processi in esecuzione, potete facilmente ottenere la maschera di bit guardando in `/proc/$PID/status`:

```bash
$ grep Cap "/proc/$(pidof chronyd)/status"
CapInh:	0000000000000000
CapPrm:	0000000002000400
CapEff:	0000000002000400
CapBnd:	000001c08380fddf
CapAmb:	0000000000000000
```

Ed è più semplice da leggere una volta decodificata:

```bash
$ pscap -p $(pidof chronyd)
ppid  pid   uid         command             capabilities
1     1803  chrony      chronyd             net_bind_service, sys_time +
```

oppure con l'aiuto di `capsh` (dal pacchetto `libcap-progs`):

```bash
$ capsh --decode=000001c08380fddf 
0x000001c08380fddf=cap_chown,cap_dac_override,cap_dac_read_search,cap_fowner,cap_fsetid,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_broadcast,cap_net_admin,cap_net_raw,cap_ipc_lock,cap_ipc_owner,cap_sys_nice,cap_sys_resource,cap_sys_time,cap_setfcap,cap_perfmon,cap_bpf,cap_checkpoint_restore
```

## 🎯 Perché dovrebbe interessarmi?

Le capabilities offrono un modo per ridurre la superficie di attacco di un sistema concedendo a ciascun servizio solo il livello minimo di privilegi di cui ha bisogno, evitando così la necessità di eseguire i servizi come utente root.

Nell'era dei microservizi, dei container e di Kubernetes, le capabilities svolgono un ruolo importante per una serie di motivi:

- *Controllo di sicurezza granulare*:
Le capabilities consentono un approccio più granulare alla concessione dei privilegi ai processi, rispetto al tradizionale accesso root "tutto o niente". Ciò consente ai container di essere eseguiti solo con i privilegi specifici di cui hanno bisogno, migliorando la sicurezza complessiva del sistema.

- *Principio del minimo privilegio*:
Assegnando solo le capabilities necessarie ai container, gli amministratori possono applicare il principio del minimo privilegio. Ciò riduce la potenziale superficie di attacco e limita i danni che potrebbero essere causati se un container venisse compromesso.

- *Compatibilità con container non-root*:
Molte organizzazioni preferiscono eseguire i container come utenti non-root per motivi di sicurezza. Le capabilities consentono a questi container non-root di eseguire specifiche operazioni privilegiate senza richiedere l'accesso root completo.

- *Kubernetes Pod Security Policies / Security Context*:
In Kubernetes, è possibile sfruttare le capabilities di Linux per definire una serie di condizioni che un pod deve soddisfare per essere accettato nel sistema. Ciò consente agli amministratori del cluster di applicare le best practice di sicurezza sull'intero cluster. Utilizzando il `SecurityContext` nel manifest di Kubernetes, è possibile impostare le capabilities nei container.

- *Isolamento dei container*:
Le capabilities aiutano a mantenere un forte isolamento tra i container e il sistema host, così come tra i diversi container, limitando ciò che ciascun container può fare.

- *Requisiti di conformità (compliance)*:
Molti standard di sicurezza e framework di conformità richiedono il principio del minimo privilegio. L'uso delle capabilities aiuta le organizzazioni a soddisfare questi requisiti consentendo comunque ai container di funzionare come necessario.

- *Flessibilità nel design dei container*:
I progettisti e sviluppatori possono progettare container che richiedono specifiche operazioni privilegiate senza la necessità di eseguire l'intero container come root, portando a progetti software più sicuri e flessibili.

## 🔗 Ulteriori letture

- [Documentazione sulla sicurezza di Docker relativa alle Linux capabilities](https://docs.docker.com/engine/security/security/#linux-kernel-capabilities)
- [Documentazione di systemd sull'ambiente di esecuzione (execution environment)](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
- [Pagina del progetto libcap-ng](https://people.redhat.com/sgrubb/libcap-ng/)

## 🏁 Conclusioni

Le capabilities di Linux rappresentano un approccio potente e flessibile alla sicurezza. Scomponendo i tradizionali privilegi di root "tutto o niente" in permessi più granulari, le capabilities consentono ad amministratori di sistema e sviluppatori di implementare efficacemente il principio del minimo privilegio.
