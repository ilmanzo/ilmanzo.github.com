---
layout: post
description: "Alcuni controlli di base per assicurarsi di aver acquistato un supporto di memoria valido per i propri file"
title: "Testare la qualità di una scheda MicroSD economica"
categories: sysadmin
tags: [hardware, storage, testing, scripting, microsd]
author: Andrea Manzini
date: 2024-09-03
---

## 💾 Introduzione

Ho appena trovato una scheda SD *molto* economica su un negozio online e, sapendo che [ci sono diversi falsi in circolazione](https://iboysoft.com/sd-card-recovery/fake-sd-card.html), ho voluto verificare rapidamente se le sue dimensioni e la sua velocità rispettano le specifiche.

Nota: dopo la prima pubblicazione, un [gentile lettore](https://www.foxyhole.io/@amreo) mi ha segnalato che gli [strumenti F3 (The F3 tools)](https://fight-flash-fraud.readthedocs.io/en/latest/introduction.html) sono perfetti per questo scopo, ed è vero; se volete seguire una strada manuale e imparare qualcosa lungo il percorso, continuate a leggere... 

## ✍️ Il test di scrittura

Cosa verificheremo? Ad esempio, voglio riempire l'intero spazio con molti file (grandi e/o piccoli) e vedere se riesco a rileggerli.
Dato che la mia scheda dovrebbe essere da 32GB, posso creare almeno 30 file da 1GB ciascuno: 

```
mmcblk0     179:0    0  30.8G  0 disk 
└─mmcblk0p1 179:1    0  30.8G  0 part /run/media/andrea/9016-4EF8
```

(nota: mmcblk0 è il nome del dispositivo per la scheda SD)

creiamo uno script che generi molti file, ne calcoli il checksum e li sposti sulla MicroSD:

```bash
#!/bin/sh
cd /tmp
DESTDIR=/run/media/andrea/9016-4EF8 # the mount path of the microsd card
for n in $(seq -w 30); do 
  dd if=/dev/random of=bigfile$n bs=1M count=1024 status=none
  sha256sum bigfile$n | tee -a checksums.txt
  time mv bigfile$n $DESTDIR
done
sync
```

eseguendo lo script, iniziamo a raccogliere l'output:

```
3cbcc7583c68115996f22745b37c02bd13b9df8d164c212883af77924bcbf113  bigfile01

real    0m42,415s
user    0m0,000s
sys     0m1,984s
005ac6aab0d0c4f08c9813fbe8f6baa6d2c4f8be41646344fbabcb9af313dc89  bigfile02

real    0m41,676s
user    0m0,004s
sys     0m1,790s
8cf990ba2e3df87db55adca975f6cc24a89e915a72dc7be2bf7be6ad0cedde47  bigfile03

real    0m41,541s
user    0m0,004s
sys     0m1,631s
2f7653161e4c2679116042598fe0298fae8fe02ada9bb72526037bcd16247fee  bigfile04

real    0m42,309s
user    0m0,000s
sys     0m1,246s
5e350cf51aba24490b4fb31bef4766ad165790b8fe510b8467668a598ef80620  bigfile05

real    0m40,725s
user    0m0,000s
sys     0m1,661s
a035ddd2161119249e5841c45036dcf5e29c8c19c16506ebf964e03baab1e7a9  bigfile06

real    0m41,860s
user    0m0,000s
sys     0m1,190s
b147d9de194fbca4499a9af77d23fe7aaedd55bacc3c9f0edd5c211f96653895  bigfile07

real    0m40,929s
user    0m0,000s
sys     0m1,744s
74e0b502a6ee6f020bb5c9acded9ace276ea28d15a6ff11e7101d5017c0dcfdc  bigfile08

real    0m41,350s
user    0m0,000s
sys     0m1,614s

[and so on]

```

Si noti che, grazie al [comando `tee`](https://www.geeksforgeeks.org/tee-command-linux-example/), il sha256sum di ogni file viene comodamente salvato in un file `checksums.txt` per un uso successivo.

Non è una misurazione propriamente *scientifica*, ma possiamo notare che scrivere circa 1GB su questa scheda richiede poco più di 40 secondi, il che significa che la **velocità di trasferimento è leggermente inferiore a ~25 MB/s** (che la qualifica come "High Speed"). Poiché questa specifica scheda era pubblicizzata come UHS-1, possiamo dire che supera il test di velocità in scrittura.

Se vogliamo "stressare" un po' il supporto, possiamo ripetere lo script più volte finché non lo riteniamo opportuno. Ora possiamo espellere la scheda, attendendo che le ultime scritture vengano completate; successivamente potremo verificare facilmente se il contenuto è lo stesso una volta riletto.

## 👀 Il test di lettura

Il programma `sha256sum` ha una speciale e comoda opzione `-c` o che accetta un file contenente le coppie di checksum e nome del file, che è esattamente ciò che abbiamo generato nel passaggio precedente:

```bash
DESTDIR=/run/media/andrea/9016-4EF8 # the mount path of the microsd card
cd $DESTDIR ; time sha256sum -c /tmp/checksums.txt
bigfile01: OK
bigfile02: OK
bigfile03: OK
bigfile04: OK
bigfile05: OK
bigfile06: OK
[...]
bigfile22: OK
bigfile23: OK
bigfile24: OK
bigfile25: FAILED
bigfile26: OK
bigfile27: OK
bigfile28: OK
bigfile29: OK
bigfile30: OK
sha256sum: WARNING: 1 computed checksum did NOT match
sha256sum -c /tmp/checksums.txt  154,26s user 23,13s system 49% cpu 5:55,02 total

```

La velocità di lettura misurata è di circa 192 MB/s, anche se la cache del filesystem gioca un ruolo importante qui. 

## ⚠️ Conclusioni

La parte interessante del test finale è che alcuni file hanno fallito il controllo del checksum; questo potrebbe essere sufficiente per considerare questa scheda non affidabile per l'uso in produzione.
In breve: fate attenzione alle schede MicroSD economiche che acquistate, e assicuratevi di mantenere sempre un approccio orientato al testing! ✅
