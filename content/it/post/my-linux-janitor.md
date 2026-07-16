---
layout: post
title: "Pulizia automatica dei file su Linux"
description: "🚮 Ovvero: come ho insegnato al mio PC Linux a buttare la propria spazzatura"
categories: [automation, sysadmin]
tags: [linux, systemd, opensuse, timers, sysadmin, cleanup]
author: Andrea Manzini
date: 2025-10-23

---

## 🧹 Il mio disordinato sistema Linux

Con il passare degli anni, il mio sistema Linux inizia a diventare un po'... *disordinato*.

La mia directory `~/Downloads` è una vera e propria discarica digitale. È un accumulo di ISO, script di test e quelle enormi immagini di macchine virtuali da svariati gigabyte che devo testare una volta e poi dimentico. Aggiungete a questo `~/Pictures/Screenshots`, che trabocca di migliaia di catture rapide che non guarderò mai più.

Lo spazio su disco oggi costa poco, ma mi piace avere le cose in ordine e pulite. Potrei procedere a una pulizia manuale... Ma chi si ricorda di farlo?

Così ho configurato una rapida soluzione automatizzata; si è rivelata un'ottima occasione per studiare i **timer di systemd!**

La mia regola è semplice: se non ho effettuato l'accesso (o "aperto") un file in uno di questi due percorsi per 30 giorni, lo considero spazzatura e voglio che venga rimosso.

![linux janitor](/img/linux_janitor.jpg)

*(vi prego di perdonare l'immancabile e stucchevole immagine generata dall'IA)*


## 🗂️ Il tuo personale spazzino systemd

Dobbiamo solo creare due semplici file di testo:

- Un file `.service`: dice allo spazzino cosa fare.
- Un file `.timer`: dice allo spazzino quando farlo.

Prima di tutto, ci serve un posto dove posizionare i nostri nuovi file. Systemd cerca i file dell'utente in `~/.config/systemd/user/`.

```bash
mkdir -p ~/.config/systemd/user/
```

Il primo file definirà il comando di pulizia.
Create un nuovo file chiamato `~/.config/systemd/user/cleanup-files.service`:

```ini
[Unit]
Description=Clean up old files in Download and Screenshots

[Service]
Type=oneshot
ExecStart=/usr/bin/find %h/Downloads %h/Pictures/Screenshots -type f -atime +29 -delete
Nice=19
IOSchedulingClass=idle
```

Analizziamolo nel dettaglio:

- `Type=oneshot`: significa semplicemente che esegue un singolo comando e si ferma.
- `ExecStart=...`: questo è il comando magico!
- `%h/Downloads %h/Pictures/Screenshots`: `%h` è la scorciatoia speciale di systemd per la vostra home directory. Diciamo a `find` di cercare in entrambi i percorsi.
- `-type f`: trova solo file, non directory vuote.
- `-atime +29`: trova i file il cui ultimo accesso risale a più di 29 giorni fa (ovvero, 30 o più giorni).
- `-delete`: sì, li elimina.
- `Nice=19` e `IOSchedulingClass=idle`: queste sono buone maniere per il sistema. Gli dicono di eseguire questo comando con la priorità più bassa possibile, in modo da non rallentare mai il vostro lavoro reale.

nota: se il filesystem della vostra `/home/` è montato con le opzioni `noatime` o `relatime` per migliorare le prestazioni, potreste ottenere risultati più prevedibili utilizzando invece `mtime` (tempo di modifica). In questo modo verranno eliminati i file che non subiscono modifiche da 30 giorni.

⚠️ Avviso di sicurezza! Prima di lasciarlo girare, fate una prova! Copiate il comando nel terminale, ma rimuovete la parte `-delete`.

```bash
# QUESTO ELENCHERÀ SOLO I FILE. NON ELIMINERÀ NULLA.
find ~/Downloads ~/Pictures/Screenshots -type f -atime +29
```

Ora creiamo la pianificazione.

Create un nuovo file chiamato `~/.config/systemd/user/cleanup-files.timer`:

```ini
[Unit]
Description=Run cleanup-files.service daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Questo è semplice:

- `OnCalendar=daily`: esegue l'operazione una volta al giorno (solitamente intorno a mezzanotte).
- `Persistent=true`: questa è la parte migliore. Se il computer era spento a mezzanotte, eseguirà il comando non appena avviate il sistema ed effettuate l'accesso.

## ⏲️ Avviate il vostro timer!

Avete creato lo spazzino; è ora di attivarlo.
Dite a systemd di leggere i vostri nuovi file:

```bash
systemctl --user daemon-reload
```

Abilitate e avviate il timer:

```bash
systemctl --user enable --now cleanup-files.timer
```

Potete verificare che il timer sia attivo e in attesa eseguendo:

```bash
systemctl --user status cleanup-files.timer
systemctl --user list-timers
```

## 🗑️ Passaggio bonus: pulizia dei pacchetti

### (per gli utenti openSUSE 🦎)

La pulizia dei file è ottima, ma come utente Tumbleweed, il mio sistema riceve aggiornamenti costanti, che possono lasciare pacchetti "orfani" o non necessari — dipendenze che erano state installate per qualcosa ma che non sono più richieste. Per questo ho anche un comodo alias

```bash
alias zclean='zypper packages --orphaned && zypper packages --unneeded'
```

che mi mostra i pacchetti potenzialmente candidati, che posso poi rimuovere con le loro dipendenze:

```bash
zypper rm -u <PACKAGENAME>
```

Godetevi il vostro sistema più pulito e buon hacking!
