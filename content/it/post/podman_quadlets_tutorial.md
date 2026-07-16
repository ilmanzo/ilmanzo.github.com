---
title: "Una guida pratica a Podman Quadlet"
date: 2026-02-03
tags: ["opensuse", "podman", "containers", "systemd", "linux", "tutorial"]
categories: ["linux"]
author: Andrea Manzini
---

## 🦎 Ciao geeko!

Se hai eseguito container sulla tua macchina [Leap](https://get.opensuse.org/leap) o [Tumbleweed](https://get.opensuse.org/tumbleweed/), probabilmente avrai iniziato con i comandi `podman run`. Forse poi sei passato ai file `Docker Compose` per gestire gli stack. Si tratta di ottimi strumenti, ma hanno un limite: non si integrano nativamente con `systemd`, il sistema di init del tuo sistema operativo.

Quando il tuo server si riavvia, i tuoi container ripartono automaticamente? Se un container va in crash, si riavvia? Come fai a visualizzare i suoi log insieme al journal di sistema?

Oggi esploreremo i **Quadlet di Podman**.

![podman_logo](/img/podman-logo.png)


I Quadlet rappresentano il modo moderno e "nativo" di eseguire i container Podman come veri e propri servizi systemd. Se ami [openSUSE](https://www.opensuse.org/) per la sua stabilità e la sua solida progettazione, adorerai i Quadlet. Trasformano le definizioni dei container in servizi di sistema estremamente robusti, senza richiedere la scrittura manuale di complessi file unit systemd da zero.

Prepariamo la tua macchina openSUSE per utilizzare i Quadlet!

## 👤 Come Root o come Utente?

Nel mondo openSUSE attribuiamo grande valore alla sicurezza. Podman si distingue per il supporto ai container "rootless", che consentono di eseguire container con il proprio utente standard, senza bisogno di usare `sudo`.

Anche se *è possibile* eseguire i Quadlet come root (a livello di sistema), oggi ci concentreremo sui **Quadlet rootless (utente)**. È una scelta più sicura, più semplice da gestire e non richiede privilegi elevati.

## 🛠️ I prerequisiti su openSUSE

Per prima cosa, assicurati che il tuo sistema sia aggiornato e che Podman sia installato.

Apri il terminale ed esegui:

```bash
# For Leap or Tumbleweed
sudo zypper refresh
sudo zypper update
sudo zypper install podman
```

## 🎬 Configurazione dell'ambiente
Systemd deve sapere dove cercare questi file Quadlet. Per un utente rootless, esiste una directory specifica all'interno della cartella home. Di solito non esiste per impostazione predefinita, quindi creiamola.
È qui che oggi avverrà tutta la magia.

```Bash
MYDIR=~/.config/containers/systemd/
mkdir -p $MYDIR && cd $MYDIR
```

### Cos'è esattamente un Quadlet?
Un *Quadlet* è semplicemente un file di testo simile a un file INI. Al suo interno descrivi ciò di cui hai bisogno (immagine del container, porte, volumi) e systemd utilizzerà un generatore per convertire quel file in una vera e propria unità di servizio dietro le quinte.

La tipologia più comune di file Quadlet ha estensione `.container`.

## 👋 Esempio 1: il server web "Hello World" (Caddy)
Iniziamo con qualcosa di semplice. Vogliamo eseguire il [server web Caddy](https://caddyserver.com/). Desideriamo che si avvii automaticamente al boot, si riavvii in caso di crash e rimanga in ascolto sulla porta 8080.

Crea un nuovo file all'interno di `~/.config/containers/systemd/` chiamato `myserver.container`.

Puoi usare nano, [neo]vim, micro o il tuo editor di testo grafico preferito.


File: `~/.config/containers/systemd/myserver.container`

```ini
[Unit]
Description=My Caddy Web Server
# Wait until networking is up before starting
After=network-online.target

[Container]
# The image to use (always good practice to specify the registry)
Image=docker.io/library/caddy:latest

# Map host port 8080 to container port 80
PublishPort=8080:80

# Mount a volume for persistent data. 
# The ':Z' is important for SELinux on openSUSE!
Volume=caddy-data:/data:Z

[Service]
# If it crashes, restart it
Restart=always
# Give it time to pull heavy images on slower connections
TimeoutStartSec=600

[Install]
# This makes sure it starts when your user session starts (or boot via linger)
WantedBy=default.target
```

Guarda com'è leggibile! È decisamente più pulito rispetto a un enorme comando `podman run` tenuto insieme da barre rovesciate (`\`).

## ✨ La fase di attivazione "magica"
Se esegui `podman ps` in questo momento, non vedrai nulla in esecuzione. Hai creato le definizioni, ma systemd non sa ancora che esistono.

Dobbiamo indicare a systemd di scansionare la nostra directory di configurazione e generare le effettive unità di servizio. Poiché operiamo in modalità rootless, utilizziamo il flag `--user`.

Esegui questo comando nel tuo terminale:

```Bash
systemctl --user daemon-reload
```

Controlla i log del journal; se non compaiono messaggi di errore, significa che ha funzionato:

Systemd ha preso il tuo file `myserver.container` e ha generato silenziosamente un servizio chiamato `myserver.service`.

Avvia il server web:

```Bash
systemctl --user start myserver.service
```

(questa operazione richiederà un po' di tempo al primo avvio, poiché `podman` deve scaricare l'immagine del container)

Controlla lo stato del servizio:

```Bash
systemctl --user status myserver.service
```

Dovresti vedere la scritta verde che riporta "active (running)".

Mettilo alla prova! Apri Firefox e visita http://localhost:8080. Dovresti visualizzare la pagina iniziale predefinita di Caddy.

```
$ curl -I http://localhost:8080
HTTP/1.1 200 OK
Accept-Ranges: bytes
Content-Length: 18753
Content-Type: text/html; charset=utf-8
Etag: "dfzwznr2vfggegx"
Last-Modified: Wed, 28 Jan 2026 03:49:55 GMT
Server: Caddy
Vary: Accept-Encoding
Date: Tue, 03 Feb 2026 10:00:49 GMT
```


## 🗄️ Esempio 2: il database (MariaDB con Secret)
Le applicazioni reali solitamente hanno bisogno di un database, e non si dovrebbero mai inserire le password direttamente nel file di configurazione principale.

Configuriamo *MariaDB*, uno dei preferiti nell'ecosistema openSUSE, e passiamo le credenziali in modo sicuro utilizzando un file di ambiente separato.

### 1. Creare il file secret
Crea un file chiamato `mariadb.env` nella stessa directory.

File: `~/.config/containers/systemd/mariadb.env`

```Bash
MYSQL_ROOT_PASSWORD=SuperSecretOpenSUSEPassword!
MYSQL_DATABASE=myappdb
MYSQL_USER=appuser
MYSQL_PASSWORD=apppassword
```

Suggerimento per la sicurezza: su un sistema reale, esegui `chmod 600 mariadb.env` in modo che solo il tuo utente possa leggere questo file!

### 2. Creare il file del Container
Ora crea il file Quadlet che fa riferimento a quelle credenziali:

File: `~/.config/containers/systemd/mydb.container`

```ini
[Unit]
Description=MariaDB Database Service
After=network-online.target

[Container]
Image=docker.io/library/mariadb:11.8
ContainerName=production-db

# Tell Podman where to find the environment variables
EnvironmentFile=%h/.config/containers/systemd/mariadb.env

# Persistent storage for the database files
Volume=mysql-data:/var/lib/mysql:Z

# We usually don't publish DB ports to the outside world, 
# but this is just a test example. DO NOT DO THIS IN PRODUCTION!
PublishPort=127.0.0.1:3306:3306

[Service]
Restart=on-failure
TimeoutStartSec=600

[Install]
WantedBy=default.target
```

Nota: hai notato `%h` nel percorso del file? Si tratta di un identificatore di systemd che viene sostituito automaticamente con il percorso della tua directory home (ad esempio, `/home/geeko`).


## 🤹 Gestire i tuoi nuovi servizi
Ora puoi gestire questi container esattamente come fai per tutti gli altri servizi di sistema su openSUSE (come Apache, SSH o firewalld) utilizzando il comando `systemctl`.


Avvia il database:

```Bash
systemctl --user daemon-reload && systemctl --user start mydb.service
```

Visualizzare i log (alla maniera di systemd):

```Bash
journalctl --user -u mydb.service
```

Non avrai più bisogno di usare `podman logs`. Sfrutta la potenza del journal!
Per seguire i log in tempo reale:

```Bash
journalctl --user -f -u mydb.service
```

Verifichiamo se funziona:

```
$ zypper in mariadb-client
$ mariadb -h localhost -u appuser --protocol=TCP --skip-ssl -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 6
Server version: 10.11.15-MariaDB-ubu2204 mariadb.org binary distribution

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> use myappdb ; show tables;
Database changed
Empty set (0.000 sec)
```

Per un vero database pronto per la produzione avresti ovviamente bisogno di alcune ottimizzazioni extra (definire i permessi corretti per i volumi di dati, abilitare SSL, configurare la replica o i backup, ecc.), ma il concetto è chiaro :smile:


## 🥾 Il tocco finale: avvio al boot
Al momento, se riavvii la tua macchina openSUSE, questi container non si avvieranno finché non effettuerai l'accesso tramite interfaccia grafica o SSH.

Per far sì che i container rootless si avviino istantaneamente all'accensione del server (ancora prima che tu effettui il login), devi abilitare il "lingering" per il tuo account utente.

Per impostazione predefinita, le istanze utente di systemd vengono avviate al momento del login e arrestate al logout. Abilitare il lingering indica a systemd di avviare il gestore dei servizi utente al boot e mantenerlo in esecuzione anche quando non sei connesso. Questo è fondamentale per i server, poiché garantisce che i tuoi container vengano avviati subito all'accensione della macchina, senza attendere l'apertura di una sessione utente.


Esegui questo comando una volta:

```Bash
# Replace 'geeko' with your actual username
sudo loginctl enable-linger geeko
```

Ora abilita i tuoi servizi in modo che si avviino automaticamente:

```Bash
systemctl --user enable myserver.service
systemctl --user enable mydb.service
```

Suggerimento: a scopo di debug, puoi sempre ispezionare e leggere i file unit di systemd *generati* guardando in `/var/run/user/$UID/systemd/generator`:

```
$ ls -l /var/run/user/1000/systemd/generator

drwxr-xr-x. 2 andrea andrea   80 Feb  3 11:50 default.target.wants
-rw-r--r--. 1 andrea andrea 1335 Feb  3 11:50 mydb.service
-rw-r--r--. 1 andrea andrea 1320 Feb  3 11:50 myserver.service
```

Questo è tutto per ora! Ora hai un ambiente di container flessibile, profondamente integrato nel tuo sistema openSUSE. 
In un prossimo post esploreremo funzionalità più avanzate, come la *rete interna* (comunicazione container-to-container), i *limiti sulle risorse*, gli *health check*, la *gestione dei secret* e altro ancora.
Buon divertimento con Podman!