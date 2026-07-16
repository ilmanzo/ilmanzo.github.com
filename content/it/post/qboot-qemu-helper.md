---
layout: post
title: "Dal mal di testa con QEMU alla modalità Headless"
description: "Domare un mostro della riga di comando"
categories: [programming, testing]
tags: [testing, tutorial, linux, qemu, golang, virtualization, emulation, scripting]
author: Andrea Manzini
date: 2025-09-28

---

## 😸 TL;DR

Essendo pigro, ho creato [uno strumento](https://github.com/ilmanzo/q2boot) per eseguire immagini `qcow2` a mia comodità. Ora supporta x86_64, aarch64, s390x e ppc64le. Sentitevi liberi di usarlo se lo trovate utile! 

## 📖 La storia

Se avete mai digitato `qemu-system-x86_64` nel vostro terminale, conoscete bene la sensazione. Una paura strisciante. Un sudore freddo. Il *mal di testa* da QEMU. È quella speciale emicrania riservata agli sviluppatori che sanno che passeranno i successivi dieci minuti a decifrare la cronologia della propria shell per ricordare quel flag magico per la rete.

Questa era la mia realtà quotidiana. Il mio lavoro richiede di testare software su un intero zoo di versioni di Linux attraverso architetture come **x86_64**, **aarch64**, **s390x** e **ppc64le**. Vivo di immagini `qcow2`, creandole e distruggendole continuamente. Ma ogni singolo avvio era una nuova avventura nel dimenticare i flag. Ho aggiunto `-cpu host` per le prestazioni? Mi sono ricordato di `-device usb-tablet` in modo che il mouse non sembri fare breakdance nell'angolo? 🤯

Dopo aver accidentalmente salvato per la centesima volta modifiche distruttive su un'immagine di base pulita perché avevo dimenticato `-snapshot`, ho avuto un momento di chiarezza. Un glorioso momento in cui ho ribaltato il tavolo. ╯°□°）╯︵ ┻━┻

Il mio problema non era QEMU. Era **ricordare** le opzioni di QEMU. La soluzione era semplice: costruire uno strumento in modo da potermene dimenticare.

## 🥾 Una cura per il comune raffreddore della riga di comando

Con la crescita del progetto, sono cresciute anche le mie esigenze. Avevo bisogno di uno script wrapper, un compagno per l'avvio rapido che fosse robusto, portabile e facile da manutenere. La ricetta era chiara:

Una singola pillola: un binario autonomo. Nessun effetto collaterale, nessuna dipendenza, nessun "assicurati di avere installato Python 3.9.x".

Facile da modificare: doveva essere abbastanza leggibile da evitare che il "Me del futuro" maledicesse il "Me del passato".

Lo strumento giusto per il lavoro: abbastanza potente da gestire la complessità, ma abbastanza semplice per un piccolo progetto secondario.

Inizialmente ho scritto questo strumento in D, ma guardando al futuro del progetto, sapevo di aver bisogno di qualcos'altro. Così ho deciso di riscriverlo in Go. 🐹

Go non era solo il ragazzo popolare del quartiere; per un progetto come questo, rappresentava l'evoluzione perfetta. Ha soddisfatto ognuno dei punti della mia lista dei desideri con pragmatica eleganza:

Singolo eseguibile? ✅ Go compila in un binario nativo statico per impostazione predefinita. Il mio helper q2boot è un solo file, pronto all'uso su qualsiasi sistema Linux. Deployment? Risolto.

Amore per Linux? ✅ La compilazione incrociata di Go è leggendaria. Compilare per aarch64, s390x e ppc64le da una singola macchina è banale, non un progetto che richiede un intero fine settimana.

Leggibilità e potenza? ✅✅ È qui che Go eccelle per gli strumenti CLI. La sua sintassi è pulita, semplice e incredibilmente facile da imparare. La robusta libreria standard offre tutto ciò di cui si ha bisogno per file, comandi e rete. Inoltre, funzionalità come goroutine e canali, pur essendo forse eccessive per questo strumento oggi, mi danno spazio per crescere senza sovra-ingegnerizzazione. Ha tutta la potenza di cui ho bisogno senza complicazioni.


## 💆 Headless per impostazione predefinita

Ho iniziato a creare lo strumento [q2boot](https://github.com/ilmanzo/q2boot), definendo una struttura `VirtualMachine` per contenere tutte le opzioni. Questo approccio "orientato agli oggetti" significava che la configurazione della mia macchina virtuale era nettamente separata dalla complessa logica di costruzione dei comandi QEMU. Niente più codice spaghetti! 🍝

Il mio strumento `q2boot` è stato progettato attorno ai miei due flussi di lavoro principali:

🤖 Modalità Headless (impostazione predefinita): serve per il mio lavoro quotidiano di test. Viene eseguita con `-nographic` e, cosa più importante, utilizza un `-snapshot` in modo che le mie immagini di base rimangano intatte. È veloce, pulita e usa-e-getta come un bicchiere di carta. Questa modalità è il motivo per cui ora riesco a dormire la notte.

🧑‍💻 Modalità interattiva (`-i` per "ho bisogno di vedere!"): serve per gli interventi manuali. Quando devo effettivamente accedere, creare un utente o installare qualcosa, questa modalità apre una GUI, abilita un mouse che risponde ai comandi e disabilita gli snapshot in modo che le mie modifiche vengano salvate.

Per renderlo ancora più semplice, `q2boot` crea automaticamente un file `config.json` in `~/.config/q2boot/` al primo avvio. Devo solo impostare CPU e RAM predefinite una sola volta, e ho finito. Per sempre.

## ♻️ Il glorioso risultato

Il mio flusso di lavoro è stato trasformato.

Prima di q2boot (Il mal di testa):
```bash
$ qemu-system-x86_64 -m 8G -cpu host \
   -enable-kvm -drive file=... aspetta, com'era di nuovo la sintassi per virtio? *apre Google*
```

Dopo q2boot (La beatitudine headless):
```bash
$ ./q2boot -d my-disk.qcow2
```

Tutto qui. Funziona e basta. Se devo effettuare prima della configurazione:
```bash
$ ./q2boot -d my-disk.qcow2 -w
```

Il mio mal di testa da QEMU è sparito, sostituito dal ronzio silenzioso di uno strumento che fa esattamente quello che voglio.


## 💭 Considerazioni finali

Anche se Go ha già vinto il concorso di popolarità, vale la pena ripetere perché sia perfetto per utilità pratiche a riga di comando.

- Compilazione ed esecuzione rapide: Go compila in modo incredibilmente veloce, rendendo il ciclo "modifica-compila-esegui" un piacere. Il binario risultante è performante e si avvia istantaneamente.

- La semplicità è geniale: offre un insieme ridotto e mirato di funzionalità che sono incredibilmente efficaci per la creazione di software affidabile e manutenibile. Si passa il tempo a risolvere problemi, non a combattere contro il linguaggio.

- Deploy ovunque: la possibilità di effettuare la compilazione incrociata in un singolo binario privo di dipendenze è un superpotere. Condividere lo strumento con altri o distribuirlo su macchine diverse è semplicissimo.

Quindi, la prossima volta che siete stanchi di lottare con le opzioni della riga di comando per i vostri strumenti di sviluppo, o se avete bisogno di un'utilità rapida, performante e facilmente distribuibile, fate un tentativo con Go. Potreste trovare il vostro compagno gopher personale. ✨ Ha sicuramente salvato la mia salute mentale dal Tetris di QEMU!

Il repository del progetto è disponibile all'indirizzo https://github.com/ilmanzo/q2boot . I contributi sono i benvenuti!
