---
layout: post
description: "Un resoconto personale dell'Advent of Code 2024"
title: "Resoconto dell'Advent of Code 2024"
categories: programming
tags: [programming, Rust, D, Crystal, performance, benchmark, algorithms]
author: Andrea Manzini
date: 2024-12-26
---

## 🎄 Introduzione

Dopo una [SUSE hackweek](https://hackweek.opensuse.org/24/projects/hack-on-rich-terminal-user-interfaces) davvero interessante e divertente, come ogni dicembre da qualche anno a questa parte, ho partecipato all'[Advent of Code](https://adventofcode.com/).

Prima di tutto, desidero ringraziare [Eric Wastl](https://was.tl/) perché ogni anno ci regala una fantastica e indimenticabile **avvent**-ura.

![aoc_picture](/img/aoc2024.jpeg)
[fonte dell'immagine: [Reddit](https://www.reddit.com/r/adventofcode/) [u/edo360](https://www.reddit.com/user/edo360/) ]

## ✨ Cos'è l'Advent of Code?

Più che un semplice conto alla rovescia per il Natale, *AoC* è un gioco divertente che invita gli sviluppatori di ogni età e livello ad affinare le proprie capacità di problem-solving e di programmazione. Come un calendario dell'avvento virtuale, AoC propone un nuovo enigma di programmazione ogni giorno, dal 1° al 25 dicembre. Questi rompicapi sono spesso ingannevolmente semplici a prima vista, ma si rivelano rapidamente sfide intricate che richiedono algoritmi intelligenti e codice efficiente.

Nel corso degli anni il numero di partecipanti è costantemente aumentato, con quasi *300.000* utenti che hanno completato almeno un puzzle.
Quest'anno è stato davvero speciale perché è il 10° anniversario, quindi alla fine sono riuscito a completare **TUTTI** i puzzle e **raggiungere 500 Stelle!**

![500_stars](/img/aoc2024_stars.png)

## 🎁 Alcuni punti salienti personali

Come scelta deliberata, ho risolto la maggior parte delle giornate utilizzando un mix di due linguaggi: il [D Programming Language](https://dlang.org/) e il [Crystal Programming Language](https://crystal-lang.org/). Desidero esplorarli entrambi più a fondo, e AoC sembrava il terreno di gioco ideale. 

*Crystal*, con la sua sintassi simile a Ruby, mi permette di scrivere codice espressivo rapidamente, il che è ideale per le sessioni mattutine di risoluzione dei puzzle. E quando le performance diventano critiche, la natura compilata di Crystal brilla davvero.  

*D*, d'altra parte, offre potenti strumenti di metaprogrammazione che mi permettono di sperimentare diversi approcci e creare soluzioni riutilizzabili. Inoltre, le sue funzionalità moderne e la sua combinazione di capacità ad alto e basso livello lo rendono un piacere da usare.

Nonostante siano meno conosciuti, penso che siano ottimi linguaggi da utilizzare e che dovrebbero essere più diffusi nell'ambiente IT, quindi ho colto l'occasione per sostenerli e diffonderne la conoscenza. Se siete curiosi, potete trovare la maggior parte delle soluzioni nel mio repository [GitHub](https://github.com/ilmanzo/advent_of_code/tree/master/2024), ma tenete presente che questo **non** è inteso come codice pronto per la produzione; è scritto solo per divertimento alle 6 del mattino ed è privo di qualsiasi best practice: al contrario, è il mio momento di vacanza ed esperimento per fare qualche trucco sporco e scrivere codice conciso, quasi illeggibile di proposito... Siete avvisati 😅

Se capite l'italiano e volete sentirmi parlare dell'Advent of Code, ho avuto anche il piacere di essere ospite in una [puntata del podcast](https://pointerpodcast.it/p/pointer234-advent-of-code-grandmaster-con-andrea-manzini/) dei ragazzi di [Pointer Podcast](https://pointerpodcast.it/) 🎙️. Consigliatissimo iscriversi!

Tra tutti i 25 puzzle risolti durante il mese, posso citare:

- Il [Giorno 1](https://adventofcode.com/2024/day/1) come inizio offre una partenza semplice da affrontare con molti approcci diversi
- Il [Giorno 3](https://adventofcode.com/2024/day/3) perché permette di familiarizzare con le espressioni regolari e alcuni casi limite
- Il [Giorno 6](https://adventofcode.com/2024/day/6) come primo problema basato su "griglia", facile ma con la seconda parte non banale; ricorda anche un meccanismo già visto in alcuni videogiochi
- Il [Giorno 7](https://adventofcode.com/2024/day/7), un problema semplice per migliorare la propria abilità con la ricorsione e il backtracking
- Il [Giorno 8](https://adventofcode.com/2024/day/8) e il [Giorno 13](https://adventofcode.com/2024/day/13) per giocare con la matematica vettoriale
- Il [Giorno 9](https://adventofcode.com/2024/day/9) per l'idea di implementare un deframmentatore di disco molto elementare
- Il [Giorno 12](https://adventofcode.com/2024/day/12) giardinaggio: misurazione del perimetro e dell'area di forme bizzarre
- Il [Giorno 14](https://adventofcode.com/2024/day/14) robot in movimento: un inaspettato colpo di scena nella seconda parte!
- Il [Giorno 15](https://adventofcode.com/2024/day/15) istruire un robot per giocare a una variante di [sokoban](https://en.wikipedia.org/wiki/Sokoban)
- Il [Giorno 16](https://adventofcode.com/2024/day/16) e il [Giorno 20](https://adventofcode.com/2024/day/20) puzzle di labirinti con un risvolto di "Race Condition", in cui i giocatori possono passare attraverso alcune pareti grazie a un "glitch"
- Il [Giorno 21](https://adventofcode.com/2024/day/21) in cui persino la definizione del problema è ricorsiva: devi controllare un robot che controlla un altro robot che controlla un robot per premere dei pulsanti...
- Il [Giorno 23](https://adventofcode.com/2024/day/23) e il [Giorno 24](https://adventofcode.com/2024/day/24) due classici problemi teorici su [grafi](https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm) e logica booleana
- Il [Giorno 25](https://adventofcode.com/2024/day/25) un ultimo problema facile che può essere risolto in molti modi, con un'attenzione speciale all'ottimizzazione delle performance

In base ai tempi della [Leaderboard](https://aoc.xhyrom.dev/), i giorni più difficili sono stati il [15](https://adventofcode.com/2024/day/15), il [17](https://adventofcode.com/2024/day/17), il [21](https://adventofcode.com/2024/day/21) e il [24](https://adventofcode.com/2024/day/24). Sono totalmente d'accordo, andate a darci un'occhiata se vi piacciono le sfide difficili 😁 

## 🎅 Non sei solo
Una menzione speciale alla community: la cosa migliore dell'[Advent of Code](https://adventofcode.com/) è far parte di un'esperienza collettiva, dove ogni giorno puoi condividere opinioni, ricevere o dare consigli, leggere meme divertenti e giocare insieme a un sacco di persone in gamba. Che si tratti di [Reddit](https://www.reddit.com/r/adventofcode) o dei tuoi amici locali, di un gruppo Telegram o di un canale Slack, condividerlo con altre persone è il vero motivo per cui è così piacevole.

- *La collaborazione stimola la creatività*: affrontare l'AoC con amici o colleghi apre un mondo di intuizioni condivise e diversi approcci di problem-solving, portando a momenti di illuminazione ("aha!") che potresti perdere da solo.
- *Motivazione e responsabilità*: sapere che altri stanno lavorando agli stessi puzzle ti mantiene motivato e impegnato, anche quando le sfide si fanno difficili.
- *Apprendimento e condivisione delle competenze*: spiegare le tue soluzioni e discutere diverse tecniche di programmazione con gli altri consolida la tua comprensione e ti espone a nuove idee.
- *Competizione amichevole e cameratismo*: una piccola competizione amichevole può essere un ottimo motivatore, e festeggiare i successi insieme rende l'esperienza ancora più gratificante.
- *Trasformare la programmazione in un evento sociale*: AoC può diventare una divertente attività sociale, sia attraverso gruppi online che sessioni di programmazione di persona con gli amici.

## ☃️ Considerazioni finali

Che tu sia uno sviluppatore esperto o che tu stia appena iniziando il tuo viaggio nella programmazione, [Advent of Code](https://adventofcode.com/) offre un'esperienza unica e gratificante. Oltre alla soddisfazione di risolvere puzzle intricati, è un'opportunità per esplorare nuovi linguaggi di programmazione, ottimizzare il tuo codice per l'efficienza e imparare da una vivace community di colleghi sviluppatori. Quindi, abbraccia lo spirito natalizio, prendi il tuo linguaggio di programmazione preferito e tuffati nell'affascinante mondo di Advent of Code. Chissà, potresti scoprire un nuovo trucco o due lungo il percorso!

Anche se l'avvento di quest'anno è terminato, i puzzle sono ancora online: puoi provare a risolverli in qualsiasi momento.

*ps:*
Se ti interessano Rust e l'ottimizzazione estrema delle prestazioni, ti consiglio di dare un'occhiata ad [Advent of CodSpeed](https://codspeed.io/advent) 🐇 
