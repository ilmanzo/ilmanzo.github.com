---
layout: post
description: "Resoconto personale della conferenza GoLab 2024"
title: "Resoconto del GoLab 2024"
categories: conference
tags: [go, golang, programming, developers, SUSE, conference]
author: Andrea Manzini
date: 2024-11-15
---

## Introduzione

Dal 2015, il GoLab è una delle conferenze più storiche e rinomate al mondo sull'ecosistema del [Go Programming Language](https://go.dev/), attirando un vasto pubblico di Gopher da ogni angolo del pianeta. 

{{< figure src="/img/golab_2024/IMG_20241113_074003.jpg" height=300 link="/img/golab_2024/IMG_20241113_074003.jpg" caption="Errore mio, ho dimenticato di fare una foto alla maglietta 🤷" >}} 

Negli ultimi anni, gli [organizzatori](https://www.develer.com/en/) hanno ospitato alcuni dei più grandi nomi del settore, che hanno condiviso le proprie intuizioni ed esperienze con i partecipanti.

Come prima impressione di benvenuto, la sede era uno splendido hotel nell'affascinante città di Firenze ⚜️; adoro questo posto e non c'è molto altro da aggiungere.

{{< figure src="/img/golab_2024/IMG_20241112_092235.jpg" height=300 target="_blank" link="/img/golab_2024/IMG_20241112_092235.jpg" >}} 

Scelta notevole, nel 2024 il GoLab si è tenuto nei giorni immediatamente successivi al RustLab, mentre l'anno precedente i due eventi si erano sovrapposti nella stessa location. Una scelta saggia per evitare confusione e il rischio di perdersi il proprio talk preferito!

Grandi complimenti agli [organizzatori](https://www.develer.com/en/) per aver scelto di realizzare una [conferenza sostenibile](https://golab.io/golab-for-the-planet): piantare un albero per ogni speaker, eliminare la plastica, supportare i viaggi sostenibili e offrire un menu di pranzi e snack completamente vegetariano.

I tre giorni del [programma](https://golab.io/schedule) erano fitti, con il primo riservato a workshop approfonditi. Più di 400 persone da tutto il pianeta hanno partecipato alla conferenza, con 30 speaker selezionati tra le migliori aziende del mondo (SUSE inclusa).

## Alcuni punti salienti personali

{{< figure src="/img/golab_2024/IMG_20241112_100342.jpg" height=300 target="_blank" link="/img/golab_2024/IMG_20241112_100342.jpg" caption="un benvenuto affollato" >}} 

Essendo riuscito a seguire circa la metà dei talk, ho la sensazione di essermene persi alcuni davvero ottimi; ecco un breve riassunto dei miei preferiti:

### Giorno uno

- [Russ Cox](https://hachyderm.io/@rsc) ha fatto luce su un argomento controverso ma importante: la telemetria. Come il team di Go raccoglie specifiche metriche di build {{< figure src="/img/golab_2024/IMG_20241112_101913.jpg" height=400em caption="Russ Cox" >}} 

- [Alessio Greggi](https://golab.io/speakers/greggi) di [SUSE](https://www.suse.com) ha tenuto una presentazione con demo sulla creazione automatica di [profili SECCOMP](https://en.wikipedia.org/wiki/Seccomp) utilizzando diversi strumenti, come strace e [Harpoon](https://github.com/alegrey91/harpoon). {{< figure height=300 src="/img/golab_2024/IMG_20241112_115519.jpg" link="/img/golab_2024/IMG_20241112_115519.jpg" caption="Alessio Greggi" >}}
- [Tomáš Sedláček](https://www.linkedin.com/in/tomasedlacek/) è andato a fondo delle ragioni di design per la scelta di comunicazioni I/O sincrone o asincrone.
- [Roberto Clapis](https://twitter.com/empijei) ha tenuto un workshop sulla programmazione sicura e ha parlato dell'approccio difensivo, in particolare durante il parsing di dati di input complessi e sconosciuti.
- [Alan Donovan](https://github.com/adonovan) ha spiegato come sono riusciti a scalare le prestazioni di [gopls](https://pkg.go.dev/golang.org/x/tools/gopls) (il Go Language Server) di un ordine di grandezza (10x).

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_104428.jpg" link="/img/golab_2024/IMG_20241113_104428.jpg" caption="Pause caffè e momenti di networking!" >}}

- [Teea Alarto](https://twitter.com/TeeaTime) ha parlato di un approccio pratico ed efficace all'uso dei generics (una funzionalità relativamente giovane del linguaggio Go) per scrivere codice più robusto e semplice.
- [Ron Evans](https://twitter.com/deadprogram) ci ha fatto viaggiare nel tempo in un'atmosfera da "Ritorno al futuro" (12 novembre, indizio indizio): il keynote includeva droni volanti alimentati da [tinyGo](https://tinygo.org/), acquisizione video e streaming con riconoscimento facciale e un panel di "teste parlanti" di LLM malvagie sul futuro dell'umanità; date un'occhiata alla [registrazione video](https://www.youtube.com/watch?v=T-U98y-mlIs).

{{< youtube T-U98y-mlIs >}}

Alla fine di questa lunga giornata, abbiamo festeggiato il quindicesimo anno di Go con una vera festa di compleanno! 🎂

 {{< figure height=300 src="/img/golab_2024/IMG_20241112_175133.jpg" link="/img/golab_2024/IMG_20241112_175133.jpg" target="_blank" caption="Ron Evans con il cappello di stagnola, mentre modera il panel automatizzato delle LLM" >}}


### Giorno due

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_084532.jpg" link="/img/golab_2024/IMG_20241113_084532.jpg" target="_blank" caption="Camminando verso la conferenza, sulla riva dell'Arno in una soleggiata mattina d'autunno" >}}

- [Josephine Winter](https://www.linkedin.com/in/josiewinter/) ha iniziato in ideale continuità con il giorno precedente, mostrando il suo progetto per automatizzare la routine quotidiana del suo animale domestico utilizzando Arduino e TinyGo, con un esempio reale di apertura della porta della cuccia e rilascio del cibo per cani.

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_100311.jpg" link="/img/golab_2024/IMG_20241113_100311.jpg" target="_blank" caption="Josephine appena prima di presentare il suo cane" >}}

- [Jan Mercl](https://gitlab.com/cznic) ci ha mostrato come sia possibile evitare cGo e creare una versione di *sqlite* in puro Go utilizzando il compilatore/transpiler da C a Go (modernc.org/ccgo/v4) e il supporto runtime che emula la libc del C (modernc.org/libc).

- [Davide Imola](https://twitter.com/DavideImola) si è lanciato in un'avventura tra le terre del Domain Driven Design. 

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_110218.jpg" link="/img/golab_2024/IMG_20241113_110218.jpg" target="_blank" caption="Davide Imola" >}}

- [Michele Caci](https://www.linkedin.com/in/michele-caci-47770132/) ci ha coinvolto con la sua passione per i giochi da tavolo, in particolare Ticket to Ride, usandolo come spunto per offrirci un ripasso della teoria dei grafi.

{{< figure height=300 src="/img/golab_2024/IMG_20241113_122749.jpg" link="/img/golab_2024/IMG_20241113_122749.jpg" target="_blank" caption="giocare a Ticket to Ride in Go" >}}

- [Federico Paolinelli](https://twitter.com/fedepaol) ha fornito una panoramica degli strumenti che Go offre di serie per il testing unitario delle nostre applicazioni e ha proposto una serie di nuove tecniche per scrivere test più coerenti e comprensibili che si adattino bene a un progetto Go.

{{< figure height=300 src="/img/golab_2024/IMG_20241113_140614.jpg" link="/img/golab_2024/IMG_20241113_140614.jpg" target="_blank" caption="fondamenti sui test in Go" >}}

- [Jesús Espino](https://linkedin.com/in/jesus-espino/) ha presentato un'analisi molto approfondita e dettagliata a basso livello di un binario ELF di Go, lo scopo di ciascuna sezione e come ridurre le dimensioni dei nostri binari. 
- [Takuto Nagami](https://www.linkedin.com/in/takutonagami/) ha parlato della sua libreria in puro Go [resigif](https://github.com/logica0419/resigif) per ridimensionare le GIF animate, ottenendo un significativo miglioramento delle prestazioni rispetto a strumenti classici come ImageMagick. 

{{< figure height=300 src="/img/golab_2024/IMG_20241113_153718.jpg" link="/img/golab_2024/IMG_20241113_153718.jpg" target="_blank" caption="ridimensionare GIF animate senza strumenti esterni" >}}

- infine, c'è stato tempo anche per molti interessanti lightning talk... 

{{< figure height=300 src="/img/golab_2024/IMG_20241113_164917.jpg" link="/img/golab_2024/IMG_20241113_164917.jpg" target="_blank" caption="Otter per lo sviluppo frontend" >}}

## Cosa mi porto a casa

- L'equilibrio di Go tra eredità e innovazione mi ha davvero colpito. Vedere come è maturato pur rimanendo fedele ai suoi principi fondamentali è fonte di ispirazione. È una testimonianza del design del linguaggio e della community che lo spinge in avanti. Questo mi rende ancora più entusiasta di vedere dove andrà Go in futuro!

{{< figure height=300 src="/img/golab_2024/IMG_20241113_170337.jpg" link="/img/golab_2024/IMG_20241113_170337.jpg" target="_blank" caption="Com'era Go 10 anni fa?" >}}

- La community di Go è davvero qualcosa di speciale. Incontrare così tante persone appassionate e disponibili è stato un punto saliente. Rafforza l'idea che un linguaggio sia più di una semplice sintassi; riguarda le persone che lo usano e che costruiscono insieme cose straordinarie.

- Uno dei miei maggiori apprendimenti è stato approfondire i testscript di Go. Offrono un modo così potente non solo per testare il codice, ma anche per documentare esempi e pattern di utilizzo. Sicuramente integrerò maggiormente i testscript nel mio workflow.

- I lightning talk sono stati una miniera d'oro! Il concetto di utilizzare il contesto del comando per annullare i comandi a lunga esecuzione mi ha davvero sbalordito. È una soluzione davvero elegante a un problema comune e non vedo l'ora di sperimentarla nei miei progetti.

 {{< figure height=300 src="/img/golab_2024/IMG_20241113_173725.jpg" link="/img/golab_2024/IMG_20241113_173725.jpg" caption="A presto!" >}}
