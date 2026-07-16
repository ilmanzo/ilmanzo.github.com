---
title: "'uptime' è una bugia: riavviare senza fermare il Kernel"
date: 2025-12-10
author: "Andrea Manzini"
tags: ["linux", "systemd", "sysadmin", "performance"]
categories: ["Linux", "Tutorials"]
summary: "Perché aspettare 10 minuti per il POST del BIOS? Esploriamo systemd-soft-reboot per riavviare lo userspace senza toccare l'hardware."
draft: true
---

### L'attesa estenuante

Se gestisci server fisici, conosci bene questo dolore. Esegui un aggiornamento completo del sistema, vedi una nuova versione di `glibc`, `openssl` o una libreria critica nell'elenco delle modifiche e sospiri. Sai già cosa ti aspetta.

Devi riavviare.

Sull'hardware dei server moderni, un "reboot" non è un semplice lampo veloce. È un rituale di 5 o 10 minuti che comprende il memory training, l'inizializzazione del controller RAID, i POST del BIOS e l'attesa che il BMC dia finalmente il via libera al sistema operativo per prendere il controllo.

Io sono impaziente. E di solito non ho un reale *bisogno* del reset dell'hardware. Ho solo bisogno che il software si faccia da parte e si riavvii da zero.

Ecco che entra in gioco **`systemd-soft-reboot`**.

### Di cosa si tratta?

Introdotto intorno alla versione v254 di systemd (e perfezionato nelle versioni successive), il `soft-reboot` è un riavvio limitato al solo userspace. Spegne tutti i servizi in esecuzione, smonta i file system (ove possibile) e poi **riesegue il gestore systemd (PID 1)**.

La cosa fondamentale è che **non**:
* Reimposta il kernel.
* Avvia il POST del BIOS/UEFI.
* Attende l'inizializzazione dell'hardware.

Si tratta a tutti gli effetti di un "Disconnettiti e accedi di nuovo" per l'intero sistema operativo, che avviene in pochi secondi anziché in diversi minuti.

### Il caso d'uso pratico: "L'aggiornamento delle librerie"

Il caso d'uso più pratico per un amministratore di sistema è l'applicazione degli aggiornamenti delle librerie fondamentali.

Ipotizziamo di dover aggiornare `glibc`. In passato, si eseguiva un riavvio completo per garantire che nessun processo mantenesse aperti file descriptor vecchi. Con il soft-reboot, svuoti l'intero stato dello userspace e ricarichi tutto dal disco, caricando le nuove librerie senza dover pagare la penale in termini di tempo richiesta dal riavvio dell'hardware.

### Mettiamolo alla prova

Ho avviato una macchina virtuale per fare qualche test. Il comando è incredibilmente semplice:

```bash
$ systemctl soft-reboot
```

Il sistema si arresta e si riavvia quasi istantaneamente. Ma ecco la parte interessante: controlla l'uptime dopo aver effettuato nuovamente l'accesso:

```bash
$ uptime
 18:23:45 up 4 days, 2:15,  1 user,  load average: 0.15, 0.05, 0.01
```

L'uptime non si è azzerato. Poiché il kernel non si è mai fermato, il contatore dell'uptime continua a scorrere. È un modo affascinante per confondere i sistemi di monitoraggio (o il tuo capo) se questi si affidano all'uptime per verificare l'effettivo riavvio. Tecnicamente si tratta di un riavvio, semplicemente non di quello a cui sono abituati.

### Magia avanzata: cambiare root
Questa funzionalità offre possibilità ancora più incredibili. Puoi usarla per passare interamente a un file system root differente.

Se popoli la directory `/run/nextroot/` con un file tree valido del sistema operativo, systemd-soft-reboot effettuerà un pivot in quella directory trattandola come la nuova `/`.

```Bash
# Imagine you have a new OS snapshot mounted here
$ mount /dev/vdb1 /run/nextroot

# This reboots "into" the new disk, without dropping the kernel
$ systemctl soft-reboot
```

Questa tecnica viene ampiamente utilizzata dalle distribuzioni Linux "Image Based" per applicare gli aggiornamenti in modo trasparente, spostandosi di fatto tra partizioni A/B senza richiedere un avvio a freddo.

### Far sopravvivere i servizi
Puoi persino configurare alcuni servizi affinché sopravvivano a questo riavvio. Se hai un database critico o un'attività che non può assolutamente fermarsi, puoi indicare a systemd di non toccarla mentre tutto il resto si riavvia intorno ad essa.

Aggiungi questo frammento al file unit del servizio:

```ini
[Unit]
Description=I Will Survive
DefaultDependencies=no
Conflicts=
Before=shutdown.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8000
SurviveFinalKillSignal=yes
```

Questo servizio continuerà a essere eseguito (mantenendo la propria memoria e i propri file descriptor) mentre tutto il resto viene arrestato e ricreato.

### Risorse
Se desideri approfondire l'argomento, ecco la documentazione:

[systemd-soft-reboot.service Man Page](https://www.freedesktop.org/software/systemd/man/latest/systemd-soft-reboot.service.html)

Thorsten Kukuk: systemd soft-reboot and surviving it as application (OpenSUSE Conference 2024 talk)

In sintesi: se non hai bisogno di un nuovo kernel, smetti di aspettare i tempi del tuo BIOS.