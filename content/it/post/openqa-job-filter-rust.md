---
layout: post
description: "Un'utilità per semplificare il monitoraggio dei cloni dei job di openQA"
title: "Scrivere filtri per la shell per divertimento e profitto"
categories: programming
tags: [programming, Rust, shell, command line, openqa, testing]
author: Andrea Manzini
date: 2025-01-19
---

## Perché? 

Durante il mio lavoro quotidiano mi capita a volte di dover fare il debug di [job di test openQA](https://open.qa/) falliti. 

Uno dei mantra del testing è [riprodurre il problema](https://www.testdevlab.com/blog/issue-reproduction-why-reproducing-bugs-matter) e per questo compito la community di openQA ha [sviluppato alcuni strumenti](https://github.com/os-autoinst/scripts). 

In pratica, ho spesso un output come questo qui sotto proveniente da alcune operazioni di clonazione dei job:

```
Cloning parents of sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit
1 job has been created:
 - sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit -> https://openqa.suse.de/tests/16425390
Cloning parents of sle-15-SP5-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit
1 job has been created:
 - sle-15-SP5-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit -> https://openqa.suse.de/tests/16425391
Cloning parents of sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit
1 job has been created:
 - sle-15-SP4-Server-DVD-Updates-x86_64-Build20250112-1-fips_ker_mode_gnome@64bit -> https://openqa.suse.de/tests/16425392
```

E quando voglio monitorare quei job, dovrei copiare e incollare tutti gli URL dei job e passarli come argomenti alla fantastica utilità [openqa-mon](https://github.com/os-autoinst/openqa-mon), che mostrerà e mi notificherà lo stato dei job nel terminale.

```bash
$ openqa-mon https://openqa.suse.de/tests/16425390+2
```

Immagina di dover monitorare 50 job openQA contemporaneamente. Copiare e incollare manualmente ogni URL dall'output della console in openqa-mon richiede tempo ed è soggetto a errori. Questo diventa rapidamente un collo di bottiglia nel mio workflow.

## Inizio 

Sebbene openQA offra un'interfaccia web per monitorare i job, preferisco il workflow basato su terminale di `openqa-mon` per la sua flessibilità e le sue capacità di scripting. Tuttavia, anche con `openqa-mon`, raccogliere manualmente gli URL rimane un punto dolente.

Da persona pigra, mi chiedo sempre: posso automatizzarlo? Ogni volta che mi ritrovo a fare la stessa cosa due o tre volte. 
Ovviamente sì. Lo faremo in Rust :crab:? Beh, perché no? Forse imparerò qualcosa nel processo :smile:

```
$ cargo init oqa-jobfilter
```

![crab-shell](/img/pexels-taryn-elliott-6405711.jpg)
Crediti immagine a: [@taryn-elliott](https://www.pexels.com/@taryn-elliott/)

Il progetto completo è disponibile su [GitHub](https://github.com/ilmanzo/oqa-jobfilter) ed è sotto licenza MIT.

## Definizione del problema

1. Il programma dovrebbe comportarsi come un filtro per la shell, accettando l'input tramite stdin e producendo l'output tramite stdout: `$ openqa-clone-job <myjobs> | oqa-jobfilter`
2. Il programma deve essere testabile: voglio svilupparlo utilizzando un processo di sviluppo Test-Driven, che mi permetta di modificarne il design e l'architettura interna pur mantenendo lo stesso comportamento
3. L'output deve essere ordinato e pronto per essere passato così com'è a un'invocazione di `openqa-mon`
4. L'output deve essere il più compatto possibile; ad esempio, quando ho ID di test consecutivi come https://openqa.suse.de/tests/1201, https://openqa.suse.de/tests/1202, https://openqa.suse.de/tests/1203, https://openqa.suse.de/tests/1204 posso semplicemente inviare 1201+3 a `openqa-mon`. Allo stesso modo, diversi ID di job per la stessa istanza openQA possono essere raggruppati separandoli da virgole, quindi test clonati come https://openqa.suse.de/tests/1201, https://openqa.suse.de/tests/1207, https://openqa.suse.de/tests/1210, https://openqa.suse.de/tests/1215 dovrebbero diventare


```bash
openqa-mon https://openqa.suse.de 1201,1207,1210,1215
```

## Dettagli di implementazione

Il concetto di [`Traits`](https://doc.rust-lang.org/book/ch10-02-traits.html) in Rust è essenziale per soddisfare i requisiti #1 e #2. Questo significa che non scriveremo una funzione che richiede un parametro di un tipo specifico, ma accetteremo **qualsiasi** tipo che implementi quei comportamenti di Read/Write. Questo è simile alle [interfacce](https://go.dev/tour/methods/9) di Go (or alle classi astratte nei linguaggi orientati agli oggetti) ed è un paradigma di programmazione molto potente. 

Quindi la nostra funzione main leggerà e scriverà da stdin/stdout, mentre la funzione di calcolo vera e propria leggerà/scriverà semplicemente da/su un lettore/scrittore "generico". In questo modo possiamo anche testare la funzione passando input fittizi e ispezionando gli output.

```Rust
pub fn process_input<R: Read, W: Write>(input: R, mut output: W) -> io::Result<()> {
```

Requisito #3: L'ordinamento, la [de-duplicazione](https://doc.rust-lang.org/std/vec/struct.Vec.html#method.dedup) e la formattazione sono gestiti da funzionalità incluse nella ricca libreria standard di Rust.

Il requisito #4 è il più complesso: per implementare il controllo degli ID consecutivi e il raggruppamento per lo stesso dominio dobbiamo memorizzare ogni job in una struttura dati adeguata

```Rust
pub struct OpenQAJob {
    pub domain: Domain,
    pub id: u32,
    pub consecutive_count: u32,
}
```
che a questo punto merita di essere inserita in un file sorgente separato. È un'ottima occasione per imparare come organizzare un progetto Rust e modellare i "Domain Objects". Nota che a ogni `OpenQAJob` sono associate delle funzioni (molto simili a dei "metodi"). 

## Funzionalità interessanti

- Ho cercato di utilizzare anche alcune funzionalità del linguaggio Rust:
  - [valutazione delle costanti a tempo di compilazione](https://doc.rust-lang.org/reference/const_eval.html)
  - il codice è organizzato e suddiviso in file sorgente logicamente separati
  - il linter ["clippy"](https://github.com/rust-lang/rust-clippy) è configurato per essere il più pignolo possibile
  - commenti di documentazione: possiamo estrarre facilmente la documentazione direttamente dal codice sorgente
  - unit testing per coprire tutti i casi e consentire un refactoring senza timori

- Come bonus, ho aggiunto una GitHub action per eseguire gli unit test e compilare il progetto a ogni commit+push; pronto per un ciclo di release appropriato.

## Conclusioni

La creazione di questo programma è stata una sessione di hacking rapida e senza troppi fronzoli, quindi ci sono sicuramente opportunità di miglioramento: se vuoi contribuire, sentiti libero di contattarmi e/o segnalare problemi (issue) o inviare pull request. Buon divertimento!
