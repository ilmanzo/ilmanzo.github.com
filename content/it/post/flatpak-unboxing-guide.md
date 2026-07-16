---
layout: post
title: "Flatpak: l'unboxing della sandbox"
description: "Come installare nuove applicazioni senza lasciare che il disordine delle dipendenze si sparga sul vostro tappeto"
categories: linux
tags: [linux, flatpak, sicurezza, tutorial, sistemi, sysadmin]
author: Andrea Manzini
date: 2026-05-03
---

## 📦 Quel profumo di *pacchetto nuovo*

Ci siamo passati tutti: vedi una fantastica nuova applicazione su GitHub e vuoi "scartarla" immediatamente. Ma nel tradizionale mondo Linux, aprire un pacchetto spesso assomiglia ad aprire una scatola di brillantini in salotto: prima ancora di rendersene conto, le dipendenze sono sparse ovunque, e tre mesi dopo si trovano ancora strane versioni di librerie in `/usr/lib`.

Ecco perché ho iniziato a usare **Flatpak**. È come un'esperienza di unboxing in cui la scatola rimane una scatola. Ottieni tutte le novità all'interno, ma il disordine rimane confinato. Vediamo cosa succede quando strappiamo la pellicola protettiva.

![unboxing](/img/pexels-borishamer-29202644.jpg)
[Crediti immagine: Boris Hamer](https://www.pexels.com/@314917712/)

## 🐤 Bubblewrap + OSTree: i vostri sigilli di garanzia

Quando si apre un Flatpak, ci sono due livelli di "confezionamento" che mantengono tutto al sicuro:

1.  **[Bubblewrap](https://github.com/containers/bubblewrap):** Pensatelo come il nastro adesivo trasparente di sicurezza attorno ai componenti interni. Utilizza i **namespace** di Linux per assicurarsi che l'app veda solo i propri file, senza poter "sconfinare" nel sistema operativo host. È una sandbox che tiene le mani appiccicose dell'app lontane dai file di sistema.
2.  **[OSTree](https://ostreedev.github.io/ostree/):** È il modo in cui sono conservati i "pezzi". È come un sistema di scaffali modulari. Se dieci pacchetti diversi hanno bisogno dello stesso "cavo di alimentazione" (runtime), OSTree fa in modo che ci sia un solo cavo fisico sullo scaffale. Deduplicazione: perché a nessuno servono dieci copie del runtime GNOME.

## 👣 Uno sguardo attraverso la confezione

Una delle parti migliori di un "Pack" è che viene fornito con un manifesto (manifest). Non c'è bisogno di indovinare cosa ci sia dentro o cosa stia cercando di fare. Potete sbirciare attraverso la plastica prima ancora di avviarlo.

Diamo un'occhiata al "Manuale di istruzioni" di Obsidian:

```bash
$ flatpak info --show-metadata md.obsidian.Obsidian
```

Sotto l'intestazione `[Context]`, vedrete esattamente cosa questa applicazione ha il permesso di toccare. Se richiede `network` e `pulseaudio`, sapete già che comunicherà con il web ed emetterà suoni. È la massima trasparenza del tipo "Cosa c'è nella scatola?".

## 🔧 Gestire i pacchetti: la cassetta degli attrezzi CLI

Non serve un'interfaccia grafica sofisticata per gestire i vostri pacchetti. La riga di comando è più veloce e offre un controllo maggiore sull'"unboxing".

### Le operazioni quotidiane
| Attività | Comando |
| :--- | :--- |
| **Cerca nel catalogo** | `flatpak search <nome>` |
| **Installa un nuovo pacchetto** | `flatpak install flathub <app_id>` |
| **Mostra lo scaffale** | `flatpak list --app` |
| **Aggiorna i pacchetti** | `flatpak update` |

### Buttare via gli scarti
A volte capita di "aprire" alcune app e decidere che non piacciono. Se le avete disinstallate lasciando dietro di sé il "confezionamento" in eccesso (i runtime), eseguite questo comando per ripulire il tutto:

```bash
$ flatpak uninstall --unused
```

## 🛠️ Fai da te: costruire la propria scatola

Vi siete mai chiesti quanto sia difficile inserire un proprio script in una "scatola"? È sorprendentemente semplice. Tutto ciò di cui avete bisogno è un manifesto (il progetto) e il vostro codice.

Creiamo un'app "Hello Flatpak". Innanzitutto, create uno script chiamato `hello.sh`:

```bash
#!/bin/sh
echo "Hello from inside the box! I can't see your secrets!"
```

Ora, create un file manifesto chiamato `org.test.Hello.yaml`:

```yaml
app-id: org.test.Hello
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: hello.sh
modules:
  - name: hello
    buildsystem: simple
    build-commands:
      - install -D hello.sh /app/bin/hello.sh
    sources:
      - type: file
        path: hello.sh
```

Per compilarlo e "inscatolarlo", avrete bisogno di `flatpak-builder`. Eseguite questi due comandi:

```bash
# Compila l'applicazione in una cartella chiamata 'build-dir'
$ flatpak-builder --user --install --force-clean build-dir org.test.Hello.yaml

# Esegui la tua nuova creazione
$ flatpak run org.test.Hello
```

In questo modo avete creato un'applicazione in modalità sandbox. Ha il proprio prefisso `/app` e non può toccare la vostra directory home a meno che non aggiungiate esplicitamente una sezione `finish-args` al manifesto.

## 🎨 Personalizzare la scatola a proprio piacimento

Una delle cose migliori di Flatpak è che il "Manuale di istruzioni" non è scolpito nella pietra. Se non vi piace un permesso scelto dallo sviluppatore, potete semplicemente sovrascriverlo.

### La via della CLI
Il comando `flatpak override` è il vostro migliore alleato in questo caso. Vi consente di "riconfezionare" un'app al volo.

*   **Tagliare i ponti:** Non vi fidate di un'app? Bloccate il suo accesso a internet:
    ```bash
    $ flatpak override --nosocket=network org.some.App
    ```
*   **Accesso mirato alle cartelle:** Avete bisogno che il vostro editor veda un SSD esterno?
    ```bash
    $ flatpak override --filesystem=/media/external_drive org.some.IDE
    ```
*   **Iniezione di variabili d'ambiente:** Volete forzare un tema specifico o una modalità di debug?
    ```bash
    $ flatpak override --env=DEBUG=1 org.some.App
    ```

### Il pulsante "annulla"
Se esagerate e l'app smette di funzionare, niente panico. Potete sempre ripristinare le impostazioni di fabbrica con un unico comando:
```bash
$ flatpak override --reset org.some.App
```
### Consiglio utile: Flatseal
Se preferite una dashboard visiva per gestire questi interruttori, provate **[Flatseal](https://github.com/tchx84/Flatseal)**. È esso stesso un Flatpak che offre un'interfaccia pulita per gestire i permessi di ogni app presente sul sistema. È lo strumento di ispezione di sicurezza definitivo.

## 🎁 Contenuti extra per smanettoni curiosi

Visto che stiamo esplorando la confezione a fondo, ecco tre cose extra che potete fare con i vostri Flatpak e che forse non conoscete:

### 1. Il pacchetto portatile "offline"
Avete mai desiderato passare un'app specifica a un amico senza connessione a internet, o installarla su un server isolato? Potete esportare un'app installata in un singolo file `.flatpak`:

```bash
$ flatpak create-bundle /path/to/repo my-app.flatpak org.some.App
```
*In questo modo avrete un programma di installazione portatile e autonomo!*

### 2. Anche le app CLI possono essere pacchetti!
I Flatpak non sono solo per pesanti interfacce grafiche come GIMP o Obsidian. Su Flathub potete trovare anche strumenti CLI ad alte prestazioni come `neovim`, `ffmpeg` o `btop`. Per eseguirli come se fossero nativi, basta aggiungere un alias al vostro `.bashrc`:

```bash
alias nvim='flatpak run io.neovim.nvim'
```

### 3. XDG Portal: un ponte cortese verso i file dell'host
Vi siete mai chiesti come faccia un'applicazione isolata ad aprire un file senza avere il permesso di vedere l'intero disco? Il merito è del servizio **XDG Portal**.

Quando si fa clic su "Apri", l'app chiede al *servizio Portal* (che risiede sull'host) di mostrare la finestra di selezione dei file. **Voi** scegliete il file e il Portal passa un "token" temporaneo all'app, valido *esclusivamente per quel singolo file*. È come la tessera magnetica di un hotel: vi permette di aprire la vostra stanza, ma non vi dà le chiavi di tutto l'edificio.

## 🕰️ Repository, cronologia e piccole macchine del tempo

Flatpak non è legato a un unico "Store". Utilizza i **Remotes**, che sono semplicemente repository in cui sono conservati i pacchetti.

### Aggiungere le sorgenti
La maggior parte delle persone si limita a usare Flathub, ma è possibile averne quanti se ne desidera (repo Beta, GNOME nightly, ecc.):

```bash
$ flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

### Viaggio nel tempo tra le versioni (rollback)
Questa è una funzionalità straordinaria. Poiché Flatpak utilizza OSTree, mantiene una cronologia dei vostri aggiornamenti. Se una nuova versione di un'app interrompe il vostro flusso di lavoro, potete letteralmente viaggiare indietro nel tempo.

1.  **Mostra la cronologia:**
    ```bash
    $ flatpak remote-info --log flathub org.some.App
    ```
2.  **Ripristina un commit specifico:**
    ```bash
    $ flatpak update --commit=abcdef12345 org.some.App
    ```
*Non dovrete più attendere che lo sviluppatore risolva il bug: vi basterà tornare alla versione precedente che funzionava correttamente.*

## 🏁 Conclusioni

Flatpak è in grado di trasformare qualsiasi workstation da officina disordinata a scaffalatura pulita e modulare. Potete aprire, testare e scartare "pacchetti" di software senza preoccuparvi che un file `.so` vagante possa rovinarvi la giornata.

La prossima volta che state per lanciare `sudo apt install` per installare una pesante suite di strumenti, provate a usare un Flatpak. Tenete il disordine dentro la scatola. Buon Hacking!