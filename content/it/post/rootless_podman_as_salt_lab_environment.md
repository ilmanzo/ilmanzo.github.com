---
title: "Podman rootless come ambiente di laboratorio per Salt"
date: 2026-03-18
tags: ["opensuse", "podman", "containers", "systemd", "linux", "tutorial", "salt"]
categories: ["linux"]
author: Andrea Manzini
---

## 🧂 Salt senza sudo

In continuità con [il post precedente](https://ilmanzo.github.io/it/post/podman_quadlets_tutorial/), oggi metteremo all'opera i nostri container gestiti da systemd e li utilizzeremo per alcune attività utili.

L'idea è quella di configurare un ambiente per imparare come funziona il configuration management [Salt](https://saltproject.io/) e sperimentare/smanettare con esso, senza nemmeno aver bisogno dei permessi di root o di `sudo`. Dopotutto, nel mondo delle infrastrutture, **il Salt deve scorrere**!

Configureremo quindi due container, uno come *salt master* e l'altro come *salt "minion"* (che rappresenta la macchina che verrà configurata tramite salt).

```text
    +-------------+                 +-------------+
    |             |   Pub (4505)    |             |
    | salt-master | --------------> | salt-minion |
    |             |   Ret (4506)    |             |
    |             | <-------------- |             |
    +-------------+                 +-------------+
```


## 🍳 Iniziamo a cucinare

Per il mio esperimento ho usato [openSUSE Tumbleweed](https://get.opensuse.org/tumbleweed/), in quanto mi permette di testare le ultime versioni dei miei pacchetti preferiti.

```bash
# Install prerequisites
$ sudo zypper install podman systemd-container

# For rootless containers to start on boot without the user being logged in
$ loginctl enable-linger $USER

# This directory will contain our containers (pun intended)
$ mkdir -p ~/.config/containers/systemd/

# Create the directory structure for our Salt lab
$ mkdir -p ~/salt_lab/config ~/salt_lab/srv/salt ~/salt_lab/srv/pillar

# Create the initial configuration files (so Podman mounts files, not directories)
$ touch ~/salt_lab/config/master_custom.conf
$ touch ~/salt_lab/config/minion.conf
```

Ora prepariamo i file Quadlet per i nostri due container, proprio come abbiamo fatto l'ultima volta:

```ini
# ~/.config/containers/systemd/salt-master.container
[Unit]
Description=Salt Master Lab

[Container]
Image=registry.opensuse.org/opensuse/leap:15.6
ContainerName=salt-master
HostName=salt-master
Network=saltnet

Volume=%h/salt_lab/srv/salt:/mnt/salt:Z
Volume=%h/salt_lab/srv/pillar:/mnt/pillar:Z
Volume=%h/salt_lab/config/master_custom.conf:/etc/salt/master.d/master_custom.conf:Z
# Persist our Master's keys across container restarts
Volume=%h/salt_lab/config/pki/master:/etc/salt/pki:Z

Exec=bash -c "zypper --non-interactive install salt-master && salt-master -l debug"

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```ini
# ~/.config/containers/systemd/salt-minion.container
[Unit]
Description=Salt Minion Lab
After=salt-master.service

[Container]
Image=registry.opensuse.org/opensuse/leap:15.6
ContainerName=salt-minion
HostName=salt-minion
Network=saltnet

Volume=%h/salt_lab/config/minion.conf:/etc/salt/minion.d/minion.conf:Z
# Persist our Minion's keys across container restarts
Volume=%h/salt_lab/config/pki/minion:/etc/salt/pki:Z

Exec=bash -c "zypper --non-interactive install salt-minion && salt-minion -l debug"

[Service]
Restart=always

[Install]
WantedBy=default.target
```

![podman-salt](/img/podman-salt.jpg)

## 🛡️ A cosa serve il flag :Z ?

**Podman rootless** è uno strumento orientato innanzitutto alla sicurezza.

Quando monti un volume dal tuo host all'interno di un container, i moduli di sicurezza di Linux (come SELinux) impediscono di default al container di toccare quei file. Il flag `:Z` indica a Podman:

"Ehi, sto montando questa cartella. Per favore, ricollegale l'etichetta (relabel) in modo che questo specifico container (e solo questo) abbia i permessi privati per leggere e scrivere qui."

Senza `:Z`, il tuo Salt Master vedrà le cartelle ma riceverà un errore di **Permission Denied** quando proverà a leggere i tuoi file `.sls`, perché il livello di sicurezza dell'host non riconosce l'utente root "interno" del container come proprietario valido.

Per rendere persistente il nostro lavoro, il container monterà alcuni volumi dal sistema host, quindi prepariamo le directory e il loro contenuto.

Abbiamo già creato le directory nella fase di configurazione, quindi ora possiamo popolare i file di configurazione:

```yaml
# The Master Config (`~/salt_lab/config/master_custom.conf`)
interface: 0.0.0.0
file_roots:
  base:
    - /mnt/salt
pillar_roots:
  base:
    - /mnt/pillar
```

```yaml
# The Minion Config (`~/salt_lab/config/minion.conf`)
master: salt-master
```

C'è un altro concetto nuovo qui: i container dovranno comunicare tra loro, quindi dobbiamo creare una "rete" personalizzata per loro:

```bash
podman network create saltnet
```

In una configurazione standard, i container sono spesso isolati o si affidano a indirizzi IP imprevedibili. Creando la rete personalizzata `saltnet`, abilitiamo il **Service Discovery tramite DNS interno**. Quando il Salt Minion tenta di connettersi all'host `salt-master`, non ha bisogno di conoscere un indirizzo IP; interroga semplicemente il risolutore DNS integrato nella rete di Podman. Podman intercetta questa richiesta e mappa il nome `salt-master` sull'IP interno corretto del container (ad esempio, 10.89.0.2). Ciò crea un ambiente stabile e "plug-and-play" in cui la nostra infrastruttura può trovare automaticamente il proprio "cervello" (il Master), anche se i container vengono riavviati o se vengono loro assegnati nuovi IP dietro le quinte.

Senza una rete personalizzata, Podman utilizza di default un bridge di base che non fornisce la risoluzione dei nomi. Utilizzando `saltnet`, evitiamo di cablare in modo rigido indirizzi IP fragili per orientarci verso un'infrastruttura dichiarativa in cui i servizi si trovano l'un l'altro in base alla propria identità.

Ora puoi finalmente avviare i container/servizi:

```bash
$ systemctl --user start salt-master salt-minion
```
(al primissimo avvio, potrebbe essere necessario un po' di tempo per scaricare le immagini e installare i pacchetti salt)

## 📖 Impariamo il gergo

Per un principiante, Salt può sembrare l'inventario di una cucina. Ecco la spiegazione dei termini principali:

| **Termine**         | **Definizione**                                                                                           | **Analogo a...** |
| ---------------- | -------------------------------------------------------------------------------------------------------- | ------------------- |
| **Master**       | Il server centrale che memorizza le configurazioni e impartisce i comandi.                                       | Il direttore d'orchestra       |
| **Minion**       | L'agente in esecuzione sul server di destinazione che esegue gli ordini del Master.                                | I musicisti       |
| **State (.sls)** | Un file YAML che descrive lo **stato finale desiderato** di un sistema (es. "Questo pacchetto _deve_ essere installato"). | Lo spartito musicale     |
| **Pillar**       | Dati sicuri e privati (come le password) definiti sul Master e inviati solo a Minion specifici.           | La cassaforte segreta    |
| **Grains**       | "Dati di fatto" statici su un Minion (versione del sistema operativo, CPU, RAM) che questo segnala al Master.                      | La carta d'identità         |
| **JID**          | ID del Job. Ogni comando inviato dal Master riceve un ID univoco provvisto di timestamp.                                   | La ricevuta         |


## 📡 Mi sentite adesso?


```bash
$ podman exec -it salt-minion ping -c3 salt-master 

PING salt-master.dns.podman (10.89.0.6) 56(84) bytes of data. 
64 bytes from salt-master (10.89.0.6): icmp_seq=1 ttl=64 time=0.014 ms 
64 bytes from salt-master (10.89.0.6): icmp_seq=2 ttl=64 time=0.037 ms 
64 bytes from salt-master (10.89.0.6): icmp_seq=3 ttl=64 time=0.034 ms 
64 bytes from ...
```

Accedi al master e controlla le chiavi in attesa:

```bash
$ podman exec -it salt-master bash

salt-master:/ # salt-key -L
Accepted Keys:
Denied Keys:
Unaccepted Keys:
salt-minion           <--- THIS IS THE MINION!
Rejected Keys:
```

Dobbiamo accettare la chiave!

```bash
salt-master:/ # salt-key -a salt-minion -y 
The following keys are going to be accepted:
Unaccepted Keys:
salt-minion
Key for minion salt-minion accepted.

```

Ora assicuriamoci che il master possa controllare il minion:

```bash
salt-master:/ # salt 'salt-minion' test.ping
salt-minion:
  True
```

## 🤝 La stretta di mano segreta

Quando avvii un Minion nuovo di zecca, questo non si fida ciecamente del Master, e il Master non si fida assolutamente del Minion. Ecco come si svolge lo scambio passo dopo passo:

- Non appena il servizio `salt-minion` viene avviato per la prima volta, genera la propria **coppia di chiavi RSA** (una chiave pubblica e una privata) localmente in `/etc/salt/pki/minion/`.

- Il Minion invia la propria **chiave pubblica** via rete al Master. In pratica dice: _"Ciao, sono salt-minion. Ecco la mia chiave pubblica. Vorrei entrare a far parte della tua infrastruttura."_

- Il Master riceve la chiave e la colloca in una "sala d'attesa" (la directory `/etc/salt/pki/master/minions_pre/`).

- In questa fase, se esegui `salt-key -L`, vedrai il minion in **Rosso (Unaccepted)**.
    
- Il Master non invierà ancora alcun comando a questo minion.
    
- Quando esegui `salt-key -a salt-minion`, the Master sposta quella chiave pubblica nella cartella "Accepted" (`/etc/salt/pki/master/minions/`).

- Il Master invia quindi la **propria chiave pubblica** al Minion.
    
- **Ora entrambi possiedono la chiave pubblica dell'altro.** Possono usarle per negoziare una **chiave di sessione AES** temporanea per comunicazioni cifrate e velocissime.
    
Se un hacker tentasse di impersonare il tuo `salt-minion` assegnando al proprio laptop lo stesso nome e provando a unirsi alla tua rete:

1. Il Master vedrebbe una **nuova chiave pubblica** associata a un nome già esistente.
    
2. Salt mostrerebbe un avviso di sicurezza enorme: **"Attenzione! La chiave di salt-minion è cambiata! Potrebbe trattarsi di un attacco Man-in-the-Middle!"**
    
3. Il Master rifiuterà di comunicare con il "nuovo" minion finché non avrai cancellato manualmente la vecchia chiave e accettato quella nuova.

### 🆔 Non perdere la tua identità

In una configurazione standard dei container, queste chiavi risiedono all'interno del filesystem virtuale del container. Se elimini il container senza un volume persistente per `/etc/salt/pki`, dovrai accettare nuovamente le chiavi a ogni riavvio del laboratorio!

Nella nostra definizione Quadlet, abbiamo risolto questo problema montando una directory locale dall'host (`~/salt_lab/config/pki/`) all'interno del container.

Una guida rapida (Cheat Sheet) per la gestione delle chiavi:

| **Comando**          | **Azione**                                          |
| -------------------- | --------------------------------------------------- |
| `salt-key -L`        | **Elenca** tutte le chiavi (Accepted, Unaccepted, Rejected). |
| `salt-key -a <nome>` | **Accetta** la chiave di un minion specifico.       |
| `salt-key -A`        | **Accetta tutte** le chiavi in attesa (usare con cautela!). |
| `salt-key -d <nome>` | **Elimina** una chiave (in pratica, "licenzia" il minion). |
| `salt-key -f <nome>` | **Fingerprint** - Mostra la "carta d'identità" di una chiave. |


- **Fingerprint (Impronta digitale):** Una breve stringa di lettere e numeri che rappresenta la chiave. In ambienti ad alta sicurezza, dovresti confrontare l'impronta digitale sul Minion (`salt-call key.finger`) con quella sul Master (`salt-key -F`) prima di accettarla.
    
- **PKI (Public Key Infrastructure):** L'infrastruttura a chiave pubblica usata da Salt per gestire queste chiavi.
    
- **Cifratura (Encryption):** Salt usa l'algoritmo **AES-256** per il trasferimento effettivo dei dati, che è lo standard industriale per la protezione dei dati governativi e bancari.


## 🛠️ Fare qualcosa di veramente utile

Invece di eseguire comandi manuali, Salt è dsignato per utilizzare i **File di Stato (SLS)**. Questi descrivono l'aspetto che il sistema _dovrebbe_ avere (configurazione dichiarativa).

Sulla tua **macchina host** (all'esterno del container), vai nella cartella `~/salt_lab/srv/salt` e crea un file chiamato `common_tools.sls`:


```yaml
install_useful_packages:
  pkg.installed:
    - pkgs:
      - htop
      - ripgrep
      - fzf

create_test_file:
  file.managed:
    - name: /etc/salt_was_here.txt
    - contents: |
        This minion is managed by SaltStack.
        Last updated: {{ salt['system.get_system_date_time']() }}
    - user: root
    - group: root
    - mode: '0644'
```

Ora indica al Master di applicare quella configurazione al Minion. 

```bash
podman exec -it salt-master salt 'salt-minion' state.apply common_tools
```
(questa operazione potrebbe richiedere del tempo poiché comporta l'installazione dei pacchetti)

Una volta ottenuto l'esito positivo con **Succeeded: 2**, puoi controllare il file all'interno del Minion per vedere il risultato del tuo lavoro:

```bash
podman exec -it salt-minion cat /etc/salt_was_here.txt 

This minion is managed by SaltStack. Last updated: 2026-03-17 14:11:28
```



## 🤖 Mettere il laboratorio in autopilota

Per fare in modo che il Minion rimanga sincronizzato automaticamente con i file del Master, utilizziamo una pianificazione **Highstate**. Invece di dover digitare `state.apply`, il Minion si collegherà ("check in") ogni X minuti per verificare se la sua situazione reale corrisponde alle istruzioni del Master.

Crea un nuovo file sul tuo host: `~/salt_lab/srv/salt/schedule.sls`

```yaml
# Ensure the minion checks in every 5 minutes
sync_with_master_periodically:
  schedule.present:
    - function: state.highstate
    - minutes: 5
```

Salt ha bisogno di un file `top.sls` per sapere che a ciascun Minion devono essere sempre applicati i propri stati. Crea `~/salt_lab/srv/salt/top.sls`:


```yaml
base:
  '*':
    - common_tools
    - schedule
```

Esegui questo comando una volta per indicare al Minion di avviare il proprio timer interno:

```bash
podman exec -it salt-master salt '*' state.apply
```

Ora, se aggiungi un nuovo pacchetto a `common_tools.sls` sul tuo host, non dovrai fare nulla. Entro 5 minuti, il Minion noterà la differenza e installerà automaticamente il pacchetto.

In un contesto **GitOps** strutturato, i file di stato saranno versionati in un repository, da cui il master potrà scaricarli e applicarli ai minion.

## 🚀 La vita è troppo breve per comandi lunghi

Digitare ogni volta `podman exec -it salt-master ...` può diventare noioso. Per far sì che il tuo laboratorio sembri un'installazione nativa, puoi aggiungere questi alias al tuo `~/.bashrc` o `~/.zshrc`:

```bash
$ alias salt="podman exec -it salt-master salt" 
$ alias salt-key="podman exec -it salt-master salt-key" 
$ alias salt-run="podman exec -it salt-master salt-run"
$ alias salt-logs="podman logs -f salt-master" 
$ alias minion-logs="podman logs -f salt-minion"
$ alias help-me-obi-wan="salt '*' test.ping"
```

Una volta configurati, potrai semplicemente eseguire `salt-key -L` or `salt '*' test.ping` direttamente dal terminale del tuo host.

Dopo aver configurato gli alias, puoi anche eseguire:

```Bash
$ salt '*' sys.doc
```

Questo mostrerà una documentazione enorme e ricercabile di **ogni singolo comando** che Salt è in grado di eseguire. È come avere l'intero manuale integrato direttamente nel terminale.

## 🎬 Questo è tutto

Configurare un laboratorio SaltStack non deve necessariamente significare compromettere la sicurezza del sistema host o lottare con complesse reti di macchine virtuali. Sfruttando openSUSE Tumbleweed, Podman Rootless e i Quadlet, abbiamo creato un ambiente che è sicuro, dichiarativo e automatizzato.

Che tu sia uno sviluppatore che desidera testare le modifiche alla configurazione localmente o un amministratore di sistema che si prepara per l'esame SaltStack Certified Engineer, questo approccio basato sui container fornisce un ambiente di prova rapido, usa-e-getta e di livello professionale.

La parte di "collegamento" è ormai conclusa. La tua rete è attiva, le tue chiavi sono state accettate e i tuoi minion sono pronti. L'unica domanda rimasta è: cosa automatizzerai la prossima volta?

**Sfida Bonus:** Prova ad aggiungere un secondo container minion alla tua rete `saltnet`. Riesci a usare i [Grains](https://docs.saltproject.io/salt/user-guide/en/latest/topics/grains.html) per assicurarti che Apache venga installato solo sul primo minion e Nginx solo sul secondo?

<!-- 
  (  )
   ||
  |  |
  |__|  <- Il tuo laboratorio è pronto!
-->