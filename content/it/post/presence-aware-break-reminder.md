---
layout: post
title: "Un promemoria per le pause che sa se sei alla scrivania"
description: "Un vecchio netbook Intel Atom trasformato in un sorvegliante da scrivania che ricorda di fare una pausa, con motion, espeak-ng e un piccolo servizio in Nim."
categories: [programming, hacking]
tags: [nim, linux, void, hacking, diy, retro, hardware, systems]
author: Andrea Manzini
date: 2026-09-06
---

La maggior parte dei promemoria per le pause usa un orologio. Imposti un timer da 50 minuti, poi ti allontani per 30 di quei minuti per andare a prendere un caffè. Il timer suona lo stesso, nel momento esatto in cui scade. Non sa che ti sei appena riseduto.

Ho già uno smartwatch. Mi dà un colpetto al polso quando sto seduto troppo a lungo, e aiuta, ma misura la cosa sbagliata. Guarda il mio polso, non la mia scrivania. Bastano un paio di movimenti del braccio per convincerlo che mi sono alzato. Nel frattempo io sono ancora sulla stessa sedia, davanti allo stesso schermo.

Sono anche il tipo di persona che si concentra al punto di perdere del tutto la cognizione del tempo. Di solito il primo segnale che ho esagerato è il bruciore agli occhi.

Volevo quindi qualcosa che guardasse la scrivania. In un angolo della scrivania c'è un pezzo di spazzatura elettronica del 2009: un **netbook Samsung N130** con processore Intel Atom a singolo core e 1GB di RAM. Ci gira [**Void Linux**](https://voidlinux.org/), ed è la stessa macchina che ho [trasformato in un router WiFi per la taverna]({{< ref "repurpose_old_netbook_as_wifi_repeater" >}}) qualche mese fa.

L'ho reso un sorvegliante da scrivania. Controlla se sono davvero seduto davanti alla postazione. Conta il tempo di lavoro solo mentre sono lì, e mi richiama quando resto troppo.

![taking a break](/img/pixabay-bananayota-5956897.jpg)
Crediti immagine: [Bananayota](https://pixabay.com/users/bananayota-20054590/), trovata su [Pixabay](https://pixabay.com/photos/person-sit-bench-alone-sitting-5956897/)

## TL;DR

* Un vecchio netbook Samsung N130 con Void Linux fa ora da sorvegliante da scrivania.
* [`motion`](https://motion-project.github.io/) osserva la webcam integrata. A ogni inizio e fine di movimento scrive `active` oppure `idle` in un semplice file di stato.
* Un piccolo demone in Nim legge quel file e tiene il conto del tempo continuativo alla scrivania, con una barra di avanzamento su una sola riga. Al raggiungimento del limite chiama `espeak-ng` e `wall`. Un'assenza sotto i 5 minuti non azzera il conteggio.
* Non viene registrato nulla. Il flusso video non lascia mai il netbook e nessun fotogramma finisce su disco.
* Il demone gira come servizio `runit` supervisionato e senza privilegi. Costa lo 0,01% di un core e 2 MB di RAM. `motion` è il vero costo su questo hardware.
* Strada facendo ho trovato e corretto una vera shell injection nel codice dell'allarme, un errore di quoting in `motion.conf` e due bug di visualizzazione. I dettagli sono qui sotto.

<!--more-->

---

## 🧠 L'idea: rilevare la presenza in modo passivo con la webcam

Chi rileva la presenza con una telecamera di solito carica un modello di riconoscimento facciale o di object detection, per esempio una rete neurale di OpenCV o una cascata di Haar. Per un Atom a singolo core da 1.6GHz è tanto lavoro. Ed è anche più di quanto mi serve. Non mi interessa chi è alla scrivania. Mi serve solo sapere se qualcosa nell'inquadratura si muove.

Invece di scrivere un ciclo di lettura della telecamera ho quindi usato un demone in C che fa già esattamente questo: [**`motion`**](https://motion-project.github.io/).

`motion` rileva il movimento su `/dev/video0` confrontando fotogrammi consecutivi. È economico rispetto a un modello di detection. Può anche eseguire un comando nel momento in cui decide che il movimento è iniziato o finito.

### Sulla privacy

La cosa mi sta a cuore, quindi la dico chiaramente: questo sistema non registra nulla. `motion` sa salvare immagini e video, ma qui ogni opzione di output è disattivata. I fotogrammi vengono confrontati in memoria e poi buttati. Nessuna immagine arriva sul disco, nessuna immagine esce dalla macchina, e il netbook non ha nessun account cloud collegato.

Una cosa sola attraversa il confine tra `motion` e il resto del sistema: una singola parola in un file di testo, `active` oppure `idle`. Non voglio consegnare a terzi una telecamera puntata sulla stanza in cui lavoro. Qui non c'è nessun terzo a cui consegnarla.

---

## 🔌 1. Configurare `motion` per rilevare la presenza

`motion` mette a disposizione degli hook sugli eventi. Io ne uso due:

*   `on_event_start`: parte al primo movimento rilevato, cioè quando qualcuno si è appena seduto alla scrivania.
*   `on_event_end`: parte dopo `event_gap` secondi senza movimento.

Invece di lanciare uno script di shell a ogni fotogramma, lascio che `motion` scriva una sola parola in `/tmp/presence_state`.

In `/home/andrea/webcam-capture/config/motion.conf`:
```text
event_gap 60

on_event_start echo active > /tmp/presence_state
on_event_end echo idle > /tmp/presence_state
```

Nota che non ci sono virgolette attorno ai comandi di shell. La mia prima versione le aveva, perché sembrava più ordinato, ed era sbagliata. `motion` passa l'intera riga a `/bin/sh -c` così com'è. Con un paio di virgolette esterne il `>` smette di essere una redirezione e diventa testo letterale. Il comando fallisce quindi con "not found" tutte le volte. Me ne sono accorto solo perché il file di stato non cambiava mai. Avevo collegato il rilevamento della presenza a un comando che non poteva funzionare.

`event_gap 60` significa che `motion` tollera un minuto pieno di immobilità prima di decidere che te ne sei andato. È utile, perché non vuoi che lo stato passi a `idle` ogni volta che ti fermi a pensare. Il demone in Nim qui sotto ha una seconda soglia, indipendente, di 5 minuti. È quella a decidere se un'assenza conta come pausa vera e azzera il conteggio del lavoro. Le pause brevi sopravvivono a entrambe le soglie.

Void Linux monta `/tmp/` come **`tmpfs`**, un filesystem in memoria, quindi leggere e scrivere `/tmp/presence_state` non tocca mai il disco.

`motion` gira come servizio supervisionato a sé, puntato a quella configurazione.

`/etc/sv/webcam-motion/run`:
```bash
#!/bin/sh
exec 2>&1
exec motion -n -c /home/andrea/webcam-capture/config/motion.conf
```

---

## 👑 2. Il monitor di stato in Nim, il timer e il conto alla rovescia

`motion` si occupa in C della cattura video e dell'analisi dei fotogrammi, quindi il demone deve solo leggere `/tmp/presence_state` ogni pochi secondi e tenere un timer.

L'ho scritto in [**Nim**](https://nim-lang.org/), che compila in codice nativo con un runtime piccolo. Su un Atom a singolo core da 1.6GHz è una cosa che conta.

Il programma accetta tre argomenti opzionali da riga di comando:

1.  **Limite di lavoro in minuti:** minuti attivi prima dell'allarme, 60 come predefinito.
2.  **Codice lingua:** la lingua passata a `espeak-ng`, per esempio `it` oppure `en`, `it` come predefinito.
3.  **Messaggio personalizzato:** una stringa opzionale da pronunciare. Se è vuota, il demone costruisce un messaggio predefinito nella lingua scelta.

### Visualizzazione dal vivo e conto alla rovescia condiviso

Invece di stampare una riga nuova ogni 10 secondi, la riga di stato si riscrive sul posto con `\r`. Una piccola barra di avanzamento mostra quanta parte del limite di lavoro è andata:

```text
[##########----------] Active 0m 30s | Remaining 0m 30s
```

Il tempo rimanente finisce anche in `/tmp/break_countdown` a ogni tick. Anche quel file sta su `tmpfs`, quindi resta economico. Puoi portarlo in una status bar di tmux, in un prompt della shell o in una finestra di terminale piccola:
```bash
watch -n 10 cat /tmp/break_countdown
```

### Installare il sintetizzatore vocale

```bash
sudo xbps-install -S espeak-ng
```

### Il codice Nim (`break_reminder.nim`)

```nim
import std/[os, osproc, strformat, strutils]

const
  StateFile = "/tmp/presence_state"
  CountdownFile = "/tmp/break_countdown"
  TickSeconds = 10
  BreakLimit = 5 * 60 ## minimum absence (seconds) that counts as "took a break"
  BarWidth = 20

func formatTime(seconds: int): string =
  fmt"{seconds div 60}m {seconds mod 60:02}s"

func progressBar(done, total: int): string =
  let filled = clamp((done * BarWidth) div max(total, 1), 0, BarWidth)
  "[" & repeat('#', filled) & repeat('-', BarWidth - filled) & "]"

proc presenceState(): string =
  try: readFile(StateFile).strip()
  except IOError: "idle"

proc writeCountdown(text: string) =
  try: writeFile(CountdownFile, text & "\n")
  except IOError: discard

proc showStatus(line: string) =
  stdout.write "\r" & alignLeft(line, 70)
  stdout.flushFile()

proc speak(lang, text: string) =
  discard execProcess("espeak-ng", args = ["-v", lang, text], options = {poUsePath})

proc triggerAlarm(minutes: int, lang, customMsg: string) =
  echo fmt"BREAK TIME LIMIT REACHED ({minutes} minutes)!"
  let text =
    if customMsg.len > 0: customMsg
    elif lang == "it": fmt"Andrea, fai una pausa! Hai lavorato per {minutes} minuti."
    else: fmt"Andrea, please take a break! You have been working for {minutes} minutes."
  speak(lang, text)
  discard execProcess("wall", args = [fmt"TAKE A BREAK NOW! You have been active for {minutes} minutes."], options = {poUsePath})

proc parseMinutes(s: string): int =
  try: parseInt(s)
  except ValueError: 60

proc paramOrDefault(idx: int, default: string): string =
  if paramCount() >= idx and paramStr(idx).len > 0: paramStr(idx) else: default

proc main =
  let workLimitMinutes = if paramCount() >= 1: parseMinutes(paramStr(1)) else: 60
  let lang = paramOrDefault(2, "it")
  let customMsg = if paramCount() >= 3: paramStr(3) else: ""
  let workLimitSeconds = workLimitMinutes * 60

  echo "Presence-Aware Break Reminder started (Void Linux, motion-integrated)."
  echo fmt"Work limit: {workLimitMinutes}m | Language: {lang}"
  if customMsg.len > 0: echo fmt"Custom message: {customMsg}"

  var presentSeconds, absentSeconds = 0

  while true:
    sleep(TickSeconds * 1000)
    case presenceState()
    of "active":
      presentSeconds += TickSeconds
      absentSeconds = 0
      let remaining = max(0, workLimitSeconds - presentSeconds)
      showStatus fmt"{progressBar(presentSeconds, workLimitSeconds)} Active {formatTime(presentSeconds)} | Remaining {formatTime(remaining)}"
      writeCountdown(formatTime(remaining))
    else:
      absentSeconds += TickSeconds
      let remaining = max(0, workLimitSeconds - presentSeconds)
      if absentSeconds >= BreakLimit and presentSeconds > 0:
        stdout.write "\n"
        echo "Away for 5+ minutes: work clock reset."
        presentSeconds = 0
        writeCountdown("0m 00s (reset)")
      else:
        showStatus fmt"{progressBar(presentSeconds, workLimitSeconds)} Away, countdown paused: {formatTime(remaining)}"
        writeCountdown(fmt"{formatTime(remaining)} (paused)")

    if presentSeconds >= workLimitSeconds:
      stdout.write "\n"
      triggerAlarm(workLimitMinutes, lang, customMsg)
      presentSeconds = 0
      writeCountdown("0m 00s (alarm reset)")

main()
```

Questo listato è la parte del progetto che mi piace di più. Nim usa l'indentazione significativa, niente parentesi graffe e niente punti e virgola. L'inferenza di tipo tiene corte le dichiarazioni `let` e `var`. Se sai leggere Python, il ciclo qui sopra lo leggi senza dover imparare prima qualcosa di nuovo.

Sotto la superficie la somiglianza finisce. Nim è tipizzato staticamente e compila in anticipo passando per un backend C. Il risultato è un normale binario ELF, circa 70KB una volta rimossi i simboli. Sul netbook non c'è nessun interprete da installare, nessun virtual environment e nessun albero di pacchetti da tenere allineato. Copio un file solo con `scp` e `runit` lo avvia.

Lo stesso demone in Python funzionerebbe altrettanto bene. Si porterebbe però dietro il runtime di CPython e occuperebbe decine di megabyte di RAM invece di due. Su una macchina che ne ha 975 MB, la differenza è concreta.

### Come si presenta mentre gira

Ecco il demone che gira davvero, dall'inizio alla fine, sul netbook, con il limite impostato a 1 minuto per la dimostrazione (`break_reminder 1 en`). In un terminale vero ogni riga tra parentesi quadre sovrascrive la precedente tramite `\r`. Qui sotto sono divise una per riga solo per poterle leggere:

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

### Una nota sull'argomento del messaggio personalizzato

`triggerAlarm` costruisce le chiamate a `espeak-ng` e `wall` con `execProcess(..., args = [...])`, non con una stringa di shell concatenata. Non è una questione di stile. Una versione precedente costruiva il comando come `"espeak-ng -v " & lang & " \"" & text & "\""` e lo passava a una shell, cioè una injection bella e buona. Un messaggio personalizzato come `foo"; rm -rf ~ #` esce dalle virgolette ed esegue comandi arbitrari. Passare gli argomenti come array salta del tutto la shell, quindi non resta nulla da fare escaping.

L'ho verificato dando al demone un messaggio che conteneva proprio un payload del genere. Non è comparso nessun file. Al suo posto `espeak-ng` ha letto ad alta voce l'intero tentativo di exploit, parola per parola, virgolette e punti e virgola compresi. È esattamente la prova che volevo.

Il primo tentativo di correzione ha fatto emergere un secondo bug. Per impostazione predefinita `execProcess` valuta il comando tramite una shell, quindi un array `args` con le opzioni predefinite fallisce un'asserzione a runtime. La soluzione è passare `options = {poUsePath}`, che elimina la shell.

Due bug più piccoli sono saltati fuori solo dopo che il servizio è rimasto in funzione per un po'. Il conto alla rovescia perdeva l'allineamento delle colonne ogni volta che i secondi tornavano a zero, quindi `12m 0s` finiva accanto a `12m 30s`. Inoltre un argomento lingua vuoto passato dallo script del servizio svuotava la lingua configurata invece di ricadere sul valore predefinito. Entrambi si risolvono in una riga: zero padding dei secondi con `{seconds mod 60:02}`, e argomenti vuoti ignorati in `paramOrDefault`.

---

## 🐧 3. Sotto il cofano: il modello di supervisione `runit` di Void Linux

Void Linux usa **`runit`** come init e come supervisore dei servizi, al posto di systemd. È veloce, prevedibile e piccolo.

Il ciclo di vita di un servizio usa tre directory:

1.  **Il registro (`/etc/sv/`):** tutti i servizi disponibili. Ognuno è una cartella, per esempio `/etc/sv/break-reminder/`, che contiene uno script eseguibile chiamato **`run`**.
2.  **Il registro attivo (`/var/service/`):** symlink alle cartelle in `/etc/sv/`. Un symlink qui significa che il servizio è abilitato. Rimuovilo e il servizio è disabilitato.
3.  **Il supervisore:** `runsvdir` sorveglia `/var/service/`. Quando vede un nuovo symlink, fa il fork di un processo `runsv` dedicato a quel servizio.

Una volta che `runsv` esegue il servizio `break-reminder`, ha un solo compito: tenere vivo il demone. Se il demone va in crash o viene ucciso, `runsv` lo riavvia subito.

---

## 🛠️ 4. Preparare il servizio supervisionato

Compila in modalità release, ottimizzata per la dimensione, poi togli i simboli di debug con la normale utility `strip`:
```bash
nim c -d:release --opt:size break_reminder.nim
strip --strip-all break_reminder
ls -l break_reminder
```
```text
-rwxrwxr-x 1 andrea andrea 71712 Sep  5 18:14 break_reminder
```

Circa 70KB, abbastanza pochi da potersene dimenticare.

### Passo 1: creare la cartella nel registro
```bash
sudo mkdir -p /etc/sv/break-reminder
```

### Passo 2: scrivere gli script `conf` e `run`

Gli script di servizio di Void, incluso quello di `sshd`, tengono la configurazione in un file `conf` separato. Lo script `run` lo carica per primo.

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

Due dettagli meritano attenzione:

1.  **`chpst -u andrea`:** `runsv` avvia i servizi come root per impostazione predefinita. Questo demone legge e scrive solo file sotto `/tmp` e chiama `espeak-ng` e `wall`. Entrambi funzionano bene come utente normale, perché il mio account è nel gruppo `audio`. Non c'è motivo di eseguirlo come root, quindi `chpst` lascia cadere i privilegi prima di `exec`.
2.  **`exec`:** sostituisce il processo shell con il binario compilato invece di eseguirlo come figlio. In questo modo `runsv` supervisiona direttamente il demone, non una shell che gli fa da involucro.

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

In un post come questo i numeri di solito sono tirati a indovinare. Io ho invece campionato i processi in esecuzione sul netbook. Il tempo di CPU viene dai campi `utime` e `stime` di `/proc/PID/stat`, a 100 tick al secondo. La memoria residente viene da `VmRSS`.

| Processo | RSS | CPU |
|---|---|---|
| `break_reminder` | 2,0 MB | 0,01% di un core |
| `motion` | 40,4 MB | 13,6% di un core |

Il demone in Nim ha bruciato 3 tick in una finestra di 300 secondi. Sono 30 millisecondi di CPU in cinque minuti, cioè lo 0,01% di un core. È poco, ma non è zero, quindi riporto il valore reale invece di arrotondarlo via.

`motion` è il costo vero. Ha bruciato 1632 tick in una finestra di 120 secondi, cioè 16,3 secondi di CPU in due minuti. Decodificare un flusso 640x480 a 10fps su un singolo core Atom non è gratis.

### Quanto consuma tutto il sistema

Il numero più interessante non è il demone. È quanto poco serve a tutto il resto della macchina:

```text
               total        used        free      shared  buff/cache   available
Mem:             975         110          22           0         866         864
```

975 MB è ciò che il firmware lascia a Linux del gigabyte nominale. Con tutto in funzione, cioè `motion`, il promemoria delle pause, `sshd` e circa 130 processi, la macchina usa 110 MB. Togli i 40 MB che tiene `motion` e il sistema di base sta attorno ai 70 MB.

Restano 864 MB disponibili, quasi l'89% della RAM installata, su hardware venduto nel 2009. Qui non c'è nessun ambiente desktop, nessun display manager e nessun systemd. Void Linux con `runit` e una console testuale è il motivo per cui una macchina da 1GB sembra ancora spaziosa.

---

## 📊 Conclusione

Questo è un progetto di qualità della vita e di salute prima ancora che di smanettamento. Quando sono immerso in un problema, il bruciore agli occhi e le ore perse mi arrivano addosso senza preavviso. Ora c'è qualcosa che tiene il conto al posto del mio giudizio. A differenza dello smartwatch al polso, non lo inganno agitandomi sulla sedia.

I pezzi sono tutti componenti standard di Void Linux: `espeak-ng`, `runit`, `tmpfs` e gli hook sugli eventi che `motion` già offre. Sopra ci sta un binario Nim da 70KB, con i simboli rimossi. `motion` è l'inquilino pesante, e il netbook ora fa questo lavoro invece di fare da router WiFi per la taverna. Per una macchina data per obsoleta più di dieci anni fa, è una seconda carriera dignitosa.
