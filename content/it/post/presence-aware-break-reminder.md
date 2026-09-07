---
layout: post
title: "Un promemoria per le pause che sa se sei alla scrivania"
description: "Un vecchio netbook Intel Atom trasformato in un sorvegliante da scrivania che ricorda di fare una pausa, con motion, espeak-ng e un piccolo servizio in Nim."
categories: [programming, hacking]
tags: [nim, linux, void, hacking, diy, retro, hardware, systems]
author: Andrea Manzini
date: 2026-09-06
---

La maggior parte dei promemoria per le pause si basa su un semplice orologio, per cui l'allarme scatta comunque nell'istante in cui un timer da 50 minuti arriva a zero, anche se hai passato 30 di quei minuti lontano dalla scrivania a prendere un caffè, perché il timer non ha modo di sapere che ti sei già riseduto.

Ho già uno smartwatch che mi dà un colpetto al polso ogni volta che sto seduto troppo a lungo, il che aiuta, anche se misura la cosa sbagliata, dato che guarda il mio polso e non la mia scrivania, così che bastano un paio di movimenti del braccio per convincerlo che mi sono alzato, mentre io sono ancora sulla stessa sedia, davanti allo stesso schermo.

Sono anche il tipo di persona che si concentra al punto da perdere completamente la cognizione del tempo, per cui di solito il primo segnale che ho esagerato è il bruciore agli occhi.

Poiché volevo qualcosa che guardasse la scrivania al posto mio, mi sono rivolto a un pezzo di spazzatura elettronica del 2009 che sta proprio in un angolo di quella scrivania: un **netbook Samsung N130** con processore Intel Atom a singolo core e 1GB di RAM, sul quale gira [**Void Linux**](https://voidlinux.org/), la stessa macchina che ho [trasformato in un router WiFi per la taverna]({{< ref "repurpose_old_netbook_as_wifi_repeater" >}}) qualche mese fa.

L'ho reso un sorvegliante da scrivania che controlla se sono davvero seduto davanti alla postazione, conta il tempo di lavoro solo mentre sono lì, e mi richiama quando resto troppo.

![taking a break](/img/pixabay-bananayota-5956897.jpg)
Crediti immagine: [Bananayota](https://pixabay.com/users/bananayota-20054590/), trovata su [Pixabay](https://pixabay.com/photos/person-sit-bench-alone-sitting-5956897/)

## TL;DR

* L'idea di base: quando qualcosa si muove nell'inquadratura della webcam, significa che sono alla scrivania. Se resto alla scrivania troppo a lungo senza pausa, il netbook mi avvisa a voce.
* Un vecchio netbook Samsung N130 con Void Linux fa da sorvegliante da scrivania.
* [`motion`](https://motion-project.github.io/) osserva la webcam integrata e, a ogni inizio e fine di movimento, scrive `active` oppure `idle` in un semplice file di stato.
* Un piccolo demone in Nim legge quel file e tiene il conto del tempo continuativo alla scrivania con una barra di avanzamento su una sola riga, così che al raggiungimento del limite chiama `espeak-ng` e `wall`, mentre un'assenza sotto i 5 minuti non azzera mai il conteggio.
* Non viene registrato nulla, perché il flusso video non lascia mai il netbook e nessun fotogramma finisce su disco.
* Il demone gira come servizio `runit` supervisionato e senza privilegi, e costa lo 0,01% di un core e 2 MB di RAM, dato che `motion` è il vero costo su questo hardware.

<!--more-->

---

## 🧠 L'idea: rilevare la presenza in modo passivo con la webcam

Chi rileva la presenza con una telecamera di solito carica un modello di riconoscimento facciale o di object detection, per esempio una rete neurale di OpenCV o un Haar cascade, il che rappresenta tanto lavoro per un Atom a singolo core da 1.6GHz ed è anche più di quanto mi serva davvero, dato che non mi interessa chi è alla scrivania, ma solo sapere se qualcosa nell'inquadratura si muove.

Così, invece di scrivere io stesso un ciclo di lettura della telecamera, ho usato un demone in C che fa già esattamente questo: [**`motion`**](https://motion-project.github.io/).

`motion` rileva il movimento su `/dev/video0` confrontando fotogrammi consecutivi, il che è economico rispetto a un modello di detection, e può anche eseguire un comando nel momento in cui decide che il movimento è iniziato o finito.

### Sulla privacy

Poiché la cosa mi sta a cuore, vale la pena dirlo chiaramente: questo sistema non registra nulla, perché anche se `motion` sa salvare immagini e video, qui ogni opzione di output è disattivata, per cui i fotogrammi vengono confrontati in memoria e poi buttati, nessuna immagine arriva sul disco, nessuna immagine esce dalla macchina, e il netbook non ha nessun account cloud collegato.

Una sola cosa attraversa il confine tra `motion` e il resto del sistema, ed è una singola parola in un file di testo, `active` oppure `idle`, dato che non voglio consegnare a terzi una telecamera puntata sulla stanza in cui lavoro, e qui non c'è nessun terzo a cui consegnarla.

`movie_output` si può comunque riaccendere per un momento, per esempio mentre punto la webcam o mentre cerco un problema di rilevamento, dato che un filmato salvato è il modo più veloce per vedere cosa vede davvero `motion`; lo rispengo non appena la telecamera è allineata e il demone si comporta come previsto.

---

## 🔌 Configurare `motion` per rilevare la presenza

`motion` mette a disposizione degli hook sugli eventi, e io ne uso due:

*   `on_event_start`: parte al primo movimento rilevato, cioè quando qualcuno si è appena seduto alla scrivania.
*   `on_event_end`: parte dopo `event_gap` secondi senza movimento.

Invece di lanciare uno script di shell a ogni fotogramma, lascio che `motion` scriva una sola parola in `/tmp/presence_state`.

In `/home/andrea/webcam-capture/config/motion.conf`:

{{< code_import "static/files/motion.conf" "ini" >}}

Non ci sono virgolette attorno ai comandi di shell, perché `motion` passa l'intera riga a `/bin/sh -c` esattamente come è scritta, per cui racchiuderla tra virgolette trasformerebbe il `>` di redirezione in testo letterale e farebbe fallire il comando in silenzio invece di aggiornare il file di stato.

Dato che `event_gap 60` fa sì che `motion` tolleri un minuto pieno di immobilità prima di decidere che te ne sei andato, lo stato non passa a `idle` ogni volta che ti fermi a pensare. Il demone in Nim qui sotto tiene una seconda soglia, indipendente, di 5 minuti, che decide se un'assenza conta come pausa vera e azzera il conteggio del lavoro, così che le pause brevi sopravvivono a entrambe le soglie.

Poiché Void Linux monta `/tmp/` come **`tmpfs`**, un filesystem in memoria, leggere e scrivere `/tmp/presence_state` non tocca mai il disco.

`motion` gira come servizio supervisionato a sé, puntato a quella configurazione.

`/etc/sv/webcam-motion/run`:
```bash
#!/bin/sh
exec 2>&1
exec motion -n -c /home/andrea/webcam-capture/config/motion.conf
```

---

## 👑 Il monitor di stato in Nim, il timer e il conto alla rovescia

Dato che `motion` si occupa già in C della cattura video e dell'analisi dei fotogrammi, il demone deve solo leggere `/tmp/presence_state` ogni pochi secondi e tenere un timer.

L'ho scritto in [**Nim**](https://nim-lang.org/), che compila in codice nativo con un runtime piccolo, il che conta su un Atom a singolo core da 1.6GHz.

Il programma accetta tre argomenti opzionali da riga di comando:

1.  **Limite di lavoro in minuti:** minuti attivi prima dell'allarme, 60 come predefinito.
2.  **Codice lingua:** la lingua passata a `espeak-ng`, per esempio `it` oppure `en`, `it` come predefinito.
3.  **Messaggio personalizzato:** una stringa opzionale da pronunciare. Se è vuota, il demone costruisce un messaggio predefinito nella lingua scelta.

### Visualizzazione dal vivo e conto alla rovescia condiviso

Invece di stampare una riga nuova ogni 10 secondi, la riga di stato si riscrive sul posto con `\r`, mentre una piccola barra di avanzamento mostra quanta parte del limite di lavoro è già andata:

```text
[##########----------] Active 0m 30s | Remaining 0m 30s
```

Poiché il tempo rimanente finisce anche in `/tmp/break_countdown` a ogni tick, e anche quel file sta su `tmpfs`, resta abbastanza economico da poterlo portare in una status bar di tmux, in un prompt della shell o in una piccola finestra di terminale:
```bash
watch -n 10 cat /tmp/break_countdown
```

### Installare il sintetizzatore vocale

```bash
sudo xbps-install -S espeak-ng
```

### Il codice Nim (`break_reminder.nim`)

{{< code_import "static/files/break_reminder.nim" "nim" >}}

Questo listato è la parte del progetto che mi piace di più, dato che Nim usa l'indentazione significativa, niente parentesi graffe e niente punti e virgola, mentre l'inferenza di tipo tiene corte le dichiarazioni `let` e `var`, per cui se sai leggere Python, riesci a leggere il ciclo qui sopra senza dover imparare prima qualcosa di nuovo.

Sotto la superficie, però, la somiglianza finisce, perché Nim è tipizzato staticamente e compila in anticipo passando per un backend C, per cui il risultato è un normale binario ELF, circa 70KB una volta rimossi i simboli: sul netbook non c'è nessun interprete da installare, nessun virtual environment e nessun albero di pacchetti da tenere allineato, dato che copio un file solo con `scp` e `runit` lo avvia.

Anche se lo stesso demone funzionerebbe altrettanto bene in Python, si porterebbe dietro il runtime di CPython e occuperebbe decine di megabyte di RAM invece di due, il che fa una differenza concreta su una macchina che ne ha 975 MB.

### Come si presenta mentre gira

Ecco il demone che gira davvero, dall'inizio alla fine, sul netbook, con il limite impostato a 1 minuto per la dimostrazione (`break_reminder 1 en`); poiché in un terminale vero ogni riga tra parentesi quadre sovrascrive la precedente tramite `\r`, qui sotto sono divise una per riga solo per poterle leggere:

```text
Presence-Aware Break Reminder started (Void Linux, motion-integrated).
Work limit: 1m | Language: en
[###-----------------] Active 0m 10s | Remaining 0m 50s
[######--------------] Active 0m 20s | Remaining 0m 40s
[##########----------] Active 0m 30s | Remaining 0m 30s
[#############-------] Active 0m 40s | Remaining 0m 20s
[################----] Active 0m 50s | Remaining 0m 10s
[####################] Active 1m 00s | Remaining 0m 00s
BREAK TIME LIMIT REACHED (1 minutes)!
```

Ecco come suona l'allarme a sintesi vocale:
{{< audio src="/audio/alarm_it.mp3" >}}

### Una nota sull'argomento del messaggio personalizzato

Poiché `triggerAlarm` costruisce le chiamate a `espeak-ng` e `wall` con `execProcess(..., args = [...], options = {poUsePath})` invece che con una stringa di shell concatenata, nessun messaggio personalizzato può mai uscire per eseguire un secondo comando: passare gli argomenti come array salta del tutto la shell, per cui un messaggio come `foo"; rm -rf ~ #` non trova nulla da cui evadere.

L'ho verificato dando al demone un messaggio che conteneva proprio quel tipo di payload; non è comparso nessun file, e `espeak-ng` ha invece letto ad alta voce l'intero tentativo di exploit, parola per parola, virgolette e punti e virgola compresi, il che è esattamente la prova che volevo.

---

## 🐧 Sotto il cofano: il modello di supervisione `runit` di Void Linux

Al posto di systemd, Void Linux usa **`runit`** come init e come supervisore dei servizi, perché è veloce, prevedibile e piccolo.

Il ciclo di vita di un servizio usa tre directory:

1.  **Il registro (`/etc/sv/`):** tutti i servizi disponibili. Ognuno è una cartella, per esempio `/etc/sv/break-reminder/`, che contiene uno script eseguibile chiamato **`run`**.
2.  **Il registro attivo (`/var/service/`):** symlink alle cartelle in `/etc/sv/`. Un symlink qui significa che il servizio è abilitato. Rimuovilo e il servizio è disabilitato.
3.  **Il supervisore:** `runsvdir` sorveglia `/var/service/`. Quando vede un nuovo symlink, fa il fork di un processo `runsv` dedicato a quel servizio.

Una volta che `runsv` esegue il servizio `break-reminder`, ha un solo compito, che è tenere vivo il demone, per cui se il demone va in crash o viene ucciso, `runsv` lo riavvia subito.

---

## 🛠️ Preparare il servizio supervisionato

Compila in modalità release, ottimizzata per la dimensione, poi togli i simboli di debug con la normale utility `strip`:
```bash
nim c -d:release --opt:size break_reminder.nim
strip --strip-all break_reminder
ls -l break_reminder
```
```text
-rwxrwxr-x 1 andrea andrea 71712 Sep  5 18:14 break_reminder
```

Circa 70KB, abbastanza pochi da poterselo dimenticare senza pensieri.

### Passo 1: creare la cartella nel registro
```bash
sudo mkdir -p /etc/sv/break-reminder
```

### Passo 2: scrivere gli script `conf` e `run`

Poiché gli script di servizio di Void, incluso quello di `sshd`, tengono la configurazione in un file `conf` separato, lo script `run` lo carica per primo.

`/etc/sv/break-reminder/conf`:
```bash
LIMIT_MINUTES=60
LANGUAGE=it
CUSTOM_MESSAGE=
```

`/etc/sv/break-reminder/run`:
```bash
#!/bin/sh
exec 2>&1
[ -r conf ] && . ./conf
exec chpst -u andrea /home/andrea/bin/break_reminder "${LIMIT_MINUTES:-60}" "${LANGUAGE:-it}" "${CUSTOM_MESSAGE:-}"
```

Due dettagli meritano attenzione, dato che `runsv` avvia i servizi come root per impostazione predefinita, mentre questo demone legge e scrive solo file sotto `/tmp` e chiama `espeak-ng` e `wall`, entrambi funzionanti bene come utente normale perché il mio account è nel gruppo `audio`, per cui `chpst -u andrea` lascia cadere i privilegi prima di `exec`, che a sua volta sostituisce il processo shell con il binario compilato invece di eseguirlo come figlio, cosicché `runsv` finisce per supervisionare direttamente il demone e non una shell che gli fa da involucro.

### Passo 3: rendere eseguibile lo script
```bash
sudo chmod +x /etc/sv/break-reminder/run
```

### Passo 4: creare il symlink e attivare
```bash
sudo ln -s /etc/sv/break-reminder /var/service/
```

`runsvdir` intercetta il nuovo symlink e avvia il servizio.

---

## 🎛️ Gestire il servizio

```bash
sudo sv status break-reminder
sudo sv stop break-reminder
sudo sv start break-reminder
```

---

## 📏 Misure reali di consumo

Poiché in un post come questo i numeri di solito sono tirati a indovinare, ho campionato invece i processi in esecuzione sul netbook: il tempo di CPU viene dai campi `utime` e `stime` di `/proc/PID/stat`, a 100 tick al secondo, mentre la memoria residente viene da `VmRSS`.

| Processo | RSS | CPU |
|---|---|---|
| `break_reminder` | 2,0 MB | 0,01% di un core |
| `motion` | 24,3 MB | ~4,4% di un core |

Dato che il demone in Nim ha bruciato solo 3 tick in una finestra di 300 secondi, cioè 30 millisecondi di CPU in cinque minuti, il che equivale allo 0,01% di un core: è poco, ma non è zero, per cui riporto il valore reale invece di arrotondarlo via.

### Impostazioni della telecamera

L'istinto sarebbe puntare `motion` alla piena risoluzione 640x480 della telecamera, dato che è quella predefinita, ma un sorvegliante di presenza non deve riconoscere volti o testo, deve solo avere pixel a sufficienza per capire se qualcosa nell'inquadratura si è mosso. Dato che il confronto tra fotogrammi scala con il numero di pixel, tagliare la cattura a 320x240, un quarto dei pixel, taglia il costo di CPU all'incirca dello stesso fattore:

| Risoluzione | RSS | CPU |
|---|---|---|
| 640x480 | 40,4 MB | ~12,7% di un core |
| 320x240 | 24,3 MB | ~4,4% di un core |

Il parametro `framerate` di `motion` scarta solo i fotogrammi dopo che sono già stati catturati, per cui non ha senso chiedere una frequenza sotto quella nativa della telecamera: `v4l2-ctl --list-formats-ext` mostra che questa webcam offre solo due frequenze di cattura discrete, 15fps oppure 30fps, per cui `framerate` è impostato a 15.

`threshold`, il numero di pixel cambiati necessario per registrare un movimento, è un valore assoluto di pixel e non una percentuale del fotogramma, per cui deve scalare con la risoluzione: qui è impostato a `375`, calibrato sul numero totale di pixel di un fotogramma a 320x240.

Ho verificato quel valore con un movimento reale invece di fidarmi solo del calcolo: con il log di debug al massimo, seduto normalmente a digitare, senza nessun gesto plateale, è comunque comparsa una riga `motion_detected: Motion detected - starting event 1` entro 14 secondi. La risoluzione più bassa non fa perdere nulla di ciò che serve a questo progetto.

### Quanto consuma tutto il sistema

Il numero più interessante non è quello del demone, ma quanto poco serve a tutto il resto della macchina:

```text
               total        used        free      shared  buff/cache   available
Mem:             975         104         723           0         175         871
```

Poiché 975 MB è ciò che il firmware lascia a Linux del gigabyte nominale, e la macchina usa solo 104 MB con tutto in funzione, incluso il più leggero `motion` a 320x240, il promemoria delle pause, `sshd` e circa 130 processi, resta poco da spiegare una volta tolti i circa 24 MB che tiene `motion` adesso.

Restano quindi 871 MB disponibili, quasi l'89% della RAM installata, su hardware venduto nel 2009, dove non c'è nessun ambiente desktop, nessun display manager e nessun systemd, il che spiega perché Void Linux con `runit` e una console testuale faccia ancora sembrare spaziosa una macchina da 1GB.

Ecco la schermata del setup del BIOS del netbook, che ricorda le sue origini con l'Intel Atom single-core da 1.6GHz e i limiti hardware contro cui questo progetto continua a lottare:

![Samsung N130 BIOS Setup](/img/n130_2026-09-06_17-49-10.jpg)

---

## 📊 Conclusione

Dato che questo è un progetto di qualità della vita e di salute prima ancora che di smanettamento, e il bruciore agli occhi insieme alle ore perse mi arrivano addosso senza preavviso ogni volta che sono immerso in un problema, ora c'è qualcosa che tiene il conto al posto del mio giudizio, e a differenza dello smartwatch al polso, non lo inganno agitandomi sulla sedia.

I pezzi sono tutti componenti standard di Void Linux, `espeak-ng`, `runit`, `tmpfs` e gli hook sugli eventi che `motion` già offre, mentre sopra ci sta un binario Nim da 70KB con i simboli rimossi. Poiché `motion` è l'inquilino pesante, il netbook ora fa questo lavoro invece di fare da router WiFi per la taverna, il che è una seconda carriera dignitosa per una macchina data per obsoleta più di dieci anni fa.
