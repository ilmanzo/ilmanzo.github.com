---
layout: post
title: "Spiegazione della Socket Activation di systemd"
description: "Smetti di sprecare risorse: come avviare i tuoi servizi su richiesta"
categories: [linux, automation, sysadmin]
tags: [systemd, sysadmin, command line, linux, services, server, socket, learning, tutorial]
author: Andrea Manzini
date: 2025-02-02
---

## 💭 Di cosa si tratta? 

Immaginate un server web che si avvia solo quando qualcuno tenta effettivamente di accedervi. O un database che si attiva solo quando arriva una query: questa è la *magia* della socket activation (attivazione tramite socket). Il concetto non è nuovo, poiché gli amministratori di sistema di vecchia scuola ricorderanno l'uso in passato di strumenti come [inetd](https://en.wikipedia.org/wiki/Inetd) o [xinetd](https://en.wikipedia.org/wiki/Xinetd) per l'attivazione dei servizi su richiesta (on-demand).

Poiché alcuni progetti interessanti come [cockpit](https://cockpit-project.org/) hanno già iniziato a utilizzare questa funzionalità poco conosciuta, in questo blog post vedremo le basi e cercheremo di familiarizzare con gli strumenti.

## 🔑 Sotto il cofano

I componenti chiave sono:
- un file di unità `.socket`: definisce il socket (porta, protocollo) su cui ascoltare.
- un file di unità `.service`: definisce il servizio da avviare al momento della connessione.

systemd associa il file `.socket` al file `.service`:

1. systemd ascolta sul socket
2. Un client si connette al socket
3. systemd rileva la connessione
4. systemd avvia il servizio associato
5. systemd passa il socket al servizio
6. Il servizio ora gestisce direttamente la connessione

## 🔨 Mettiamoci alla prova

Partiamo da zero: [OpenSUSE Leap 16.0](https://get.opensuse.org/leap/16.0/) è in fase di α-test, quindi possiamo usarlo come campo di gioco :smile: ma alla fine potete usare la distribuzione che preferite, a patto che sia dotata del gestore dei servizi [systemd](https://systemd.io/).

Come scenario dimostrativo, supponiamo che abbiate creato un fantastico `dice-as-a-service`™ (servizio di lancio dadi) che restituisce un numero casuale ogni volta che viene invocato. Naturalmente è basato su REST e JSON! 

{{< highlight python >}}
from flask import Flask, jsonify
import random

app = Flask(__name__)

@app.route('/roll')
def roll_dice():
    return jsonify({"result": random.randint(1, 6)})
{{</ highlight >}}

(nota: questo è solo un esempio, un'applicazione di produzione vera e propria dovrebbe controllare gli input, gestire gli errori, registrare i log in modo appropriato, e così via)

{{< highlight bash  >}}
$ sudo zypper in python3-Flask
$ flask --app dice.py run &
[1] 10100
andrea@toolbox-andrea-user:/tmp>  * Serving Flask app 'dice.py'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on http://127.0.0.1:5000
Press CTRL+C to quit
{{</ highlight >}}

Testiamolo: 
{{< highlight bash  >}}
$ curl http://127.0.0.1:5000/roll 
127.0.0.1 - - [01/Feb/2025 10:30:46] "GET /roll HTTP/1.1" 200 -
{"result":2}
$ curl http://127.0.0.1:5000/roll 
127.0.0.1 - - [01/Feb/2025 10:30:49] "GET /roll HTTP/1.1" 200 -
{"result":1}
$ curl http://127.0.0.1:5000/roll 
127.0.0.1 - - [01/Feb/2025 10:30:59] "GET /roll HTTP/1.1" 200 -
{"result":6}
$ kill %1
[1]+  Terminated              flask --app dice.py run
{{</ highlight >}}

Sembra funzionare! 

## 🌿 Non sprecare risorse

Dopo alcune settimane frenetiche, scoprite che il vostro servizio è effettivamente utilizzato, ma non quanto vi aspettavate. Solo poche persone desiderano ottenere numeri casuali e solo poche volte al giorno; quindi sembra un po' uno spreco avere un interprete Python sempre in esecuzione che occupa diversi megabyte di memoria per uno scopo così limitato. Quindi, prepariamo un file di unità `socket`: 

```ini
# /etc/systemd/system/diceroll.socket 
[Unit]
Description=Socket for diceroll service activation
PartOf=diceroll.service

[Socket]
ListenStream=5000
NoDelay=true
Backlog=128

[Install]
WantedBy=sockets.target
```

e il corrispondente file `service`:

```ini
# /etc/systemd/system/diceroll.service 
[Unit]
Description=Socket-activated dice rolling service
Requires=diceroll.socket
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/dice_ng.py
Type=simple
```

Proviamolo; una nota importante: all'avvio deve essere avviata e abilitata solo l'unità `.socket`; il corrispondente file `.service` verrà avviato automaticamente su richiesta. 

```bash
$ systemctl daemon-reload
$ systemctl enable --now diceroll.socket
$ curl http://127.0.0.1:5000/roll
curl: (56) Recv failure: Connection reset by peer
```

Wow, qualcosa è andato storto :thinking:

## 🩹 Risolvere il problema

C'è un problema nella nostra soluzione: all'avvio, il server cerca di mettersi in ascolto sulla connessione ma trova il socket già occupato da systemd. Dobbiamo modificare la nostra applicazione per gestire il socket aperto e passato da systemd:

{{< highlight python >}}
import socket
import os, sys
import flask, random
from werkzeug.serving import make_server

app = flask.Flask(__name__)

@app.route('/roll')
def roll_dice():
    return {'result': random.randint(1, 6)}

def get_systemd_socket():
    """Retrieve the socket passed by systemd"""
    listen_fds = int(os.environ.get('LISTEN_FDS', 0))
    if listen_fds != 1:
        sys.stderr.write("Error: systemd did not provide exactly one socket.\n")
        sys.exit(1)
    sock = socket.fromfd(3, socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    return sock

if __name__ == '__main__':
    sock = get_systemd_socket()
    server = make_server('localhost', 5000, app, fd=sock.fileno())
    server.serve_forever()
{{</ highlight >}}


```bash
$ curl http://127.0.0.1:5000/roll
{"result":1}
```

Ora funziona e il server si avvia su richiesta. Qualcuno potrebbe notare che l'applicazione rimane in esecuzione per sempre e non si ferma mai, quindi dopo il primo avvio resta attiva e consuma risorse, anche quando è inattiva! 
D'altra parte, non possiamo semplicemente avere un servizio che gestisce una singola connessione e poi si interrompe immediatamente, poiché la gestione di molte connessioni sarebbe meno efficiente e molto simile a un server inetd/CGI. 

## 🫳 Per favore, ti fermi?

Per risolvere questo inconveniente, potremmo aggiungere alla nostra applicazione dei controlli e della logica per arrestarsi quando rimane inattiva per troppo tempo. Un effetto simile si può ottenere utilizzando l'opzione `--exit-idle-time` dell'utilità [`systemd-socket-proxyd`](https://www.freedesktop.org/software/systemd/man/latest/systemd-socket-proxyd.html); possiamo anche usare un [timer di systemd](https://documentation.suse.com/smart/systems-management/html/systemd-working-with-timers/index.html) per arrestare elegantemente la nostra applicazione dopo un periodo di tempo prestabilito. La prima soluzione è più robusta e pulita ma esula dagli scopi di questo tutorial, forse la approfondiremo in un prossimo articolo; per ora vogliamo divertirci con le funzionalità di `systemd`:

```ini
# /etc/systemd/system/diceroll.service
[Unit]
Description=Socket-activated dice rolling service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/dice_ng.py
Type=simple
TimeoutStartSec=1min  # Timeout dopo 1 minuto di inattività (nessuna nuova connessione)
# ExecStop verrà eseguito al raggiungimento di TimeoutStartSec.
ExecStop=/bin/systemctl stop your-app.service

[Install]
WantedBy=multi-user.target
```

## ⌛ Come funziona:
1. Il file `.socket` ascolta le connessioni in arrivo.
2. Quando arriva una connessione, attiva il servizio dell'applicazione (`diceroll.service`).
3. Systemd avvia il servizio dell'applicazione. Il timer `TimeoutStartSec` inizia a contare.
4. Se non arrivano nuove connessioni entro il periodo `TimeoutStartSec`, `systemd` considera fallito l'avvio del servizio ed esegue il comando `ExecStop`, che arresta l'applicazione.

## :wave: Ciao

Molti aspetti di systemd rimangono poco conosciuti, e nuove funzionalità e capacità vengono continuamente aggiunte con ogni nuova versione. Questa esplorazione ne evidenzia solo una frazione del potenziale, e un'ulteriore indagine sulle sue funzionalità più avanzate può spesso sbloccare soluzioni ancora più eleganti ed efficienti per la gestione e l'automazione dei servizi. Che si tratti di sfruttare i timer, la socket activation o esplorare le complessità di dipendenze e target, systemd offre una ricca cassetta degli attrezzi per amministratori e sviluppatori.
