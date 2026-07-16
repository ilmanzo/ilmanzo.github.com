---
layout: post
description: "Comprendere quanta energia si sta consumando"
title: "Misurare il consumo energetico dei propri programmi"
categories: linux
tags: [linux, tutorial, system, hardware, power, energy, optimization]
author: Andrea Manzini
date: 2024-06-30
---

## 🌡️ Introduzione

Per chi gestisce un datacenter, o anche un semplice server homelab, l'arrivo del caldo estivo si traduce in un aumento dell'uso dell'aria condizionata. In questo post mi sono chiesto come un ingegnere Linux possa misurare quanta energia sta consumando il sistema, in modo da poter iniziare a ragionare sull'ottimizzazione dei carichi di lavoro (workload) per ottenere pattern di consumo energetico migliori.

## 🔋 Consumo energetico in idle

Come punto di partenza, misuriamo quanta energia consuma il mio PC quando è in idle, cioè non fa assolutamente nulla; o meglio: nulla di utile ai fini del calcolo o di un servizio, ma esegue solo le solite attività predefinite del sistema operativo.

Ci sono molti modi per farlo; il più affidabile probabilmente consiste nell'utilizzare un misuratore di potenza esterno (power meter) come questo.

![powermeter](/img/powermeter.jpg) 

[immagine di pubblico dominio da Flickr; crediti a Emilian Robert Vicol](https://www.flickr.com/photos/free-stock/5000495108/)

Essendo un ingegnere del software, non mi va molto di armeggiare con i cavi; e in molte occasioni non è pratico scollegare i server in un datacenter remoto solo per fare una rapida misurazione energetica. Come soluzione puramente software, alcune misurazioni approssimative si possono ottenere con l'aiuto dell'utilità [powerstat](https://github.com/ColinIanKing/powerstat), che utilizza diversi metodi (come le statistiche della batteria o l'*interfaccia Intel RAPL*, che sta per Running Average Power Limit) per stimare il consumo energetico di un computer in funzione.

```
# powerstat -zR
[...]

-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Average   0.1   0.0   0.2  99.4   0.2  1.1  916.3  479.6  0.2  0.0  0.4  29.98 
 GeoMean   0.1   0.0   0.2  99.4   0.2  1.1  882.5  463.9  0.0  0.0  0.0  29.89 
  StdDev   0.1   0.0   0.1   0.3   0.2  0.3  408.7  169.7  0.7  0.0  2.1   2.64 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Minimum   0.1   0.0   0.1  96.9   0.1  1.0  730.0  377.0  0.0  0.0  0.0  28.74 
 Maximum   0.8   0.0   0.6  99.6   1.6  2.0 3987.0 1589.0  5.0  0.0 16.0  44.31 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
Summary:
CPU:  29.98 Watts on average with standard deviation 2.64  
Note: power read from RAPL domains: uncore, pkg-0, core, psys.
These readings do not cover all the hardware in this device.
```

## ⚡ Mettiamolo alla prova

Quindi il mio computer, un ThinkPad P15 Gen 2i, consuma circa ~30 Watt (o ~30 Joule/sec) per non fare nulla, il che, se volete il mio parere, considero piuttosto scadente. Facciamo qualche esperimento con carichi di lavoro differenti, come quello in cui ogni computer dovrebbe eccellere: il calcolo dei numeri primi!

L'idea dell'esperimento è vedere quanta energia costa ottenere il primo milione di numeri primi; in base a quanto riportato sulla [wiki dei numeri primi](https://prime-numbers.fandom.com/), il milionesimo numero primo dovrebbe essere 15.485.863.

Ho iniziato con un programma Python piuttosto semplice e volutamente non ottimizzato:

```python
from math import sqrt

def isPrime(n):
  for j in range(3,int(sqrt(n)+1),2):
    if n % j == 0:
      return False
  return True

n,i = 2,3
while n < 1_000_000:
    i += 2
    if isPrime(i):
        n += 1
print("Prime number =", i)
```

E l'ho eseguito con la misurazione di `powerstat` in background:


```
# (powerstat -zR 1 60 &) ; /usr/bin/time python3 /tmp/prime.py
```

```
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Average   6.3   0.0   0.2  93.4   0.1  2.0 1003.4 1168.7  0.1  0.0  0.5  56.65 
 GeoMean   6.3   0.0   0.1  93.4   0.0  2.0  872.7  964.3  0.0  0.0  0.0  56.26 
  StdDev   0.1   0.0   0.1   0.1   0.0  0.1  750.7 1184.1  0.4  0.1  1.7   7.55 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
 Minimum   6.3   0.0   0.1  92.7   0.0  2.0  561.0  697.0  0.0  0.0  0.0  53.39 
 Maximum   7.1   0.0   0.4  93.6   0.1  3.0 4135.0 6576.0  2.0  1.0 10.0  90.93 
-------- ----- ----- ----- ----- ----- ---- ------ ------ ---- ---- ---- ------ 
Summary:
CPU:  56.65 Watts on average with standard deviation 7.55  
Note: power read from RAPL domains: uncore, pkg-0, core, psys.
These readings do not cover all the hardware in this device.

Prime = 15485863
61.68user 0.00system 1:01.71elapsed 99%CPU (0avgtext+0avgdata 8064maxresident)k
0inputs+0outputs (0major+879minor)pagefaults 0swaps
```

Notate come i numeri variano nel tempo! Quindi, durante i calcoli, il mio PC quasi raddoppia il consumo di energia. Per andare sul sicuro, diciamo che circa ~27W è l'energia extra richiesta per eseguire il mio modesto calcolatore di numeri primi in Python.

Poiché il programma viene eseguito per circa ~61,5 secondi, l'esecuzione richiede circa ~3490 Joule di energia o 0,0009694444 kWh; naturalmente, questo si riferisce solo alla CPU e non include scheda grafica, sottosistema del disco, display, rete e così via.

## 📏 Una misurazione alternativa

Un altro modo per leggere le metriche RAPL è utilizzare la potente utilità [perf](https://perf.wiki.kernel.org/index.php/Main_Page). Questo strumento può leggere molte sonde esposte dal kernel, quindi forse in futuro dovremmo dedicargli un intero post.

```bash 
# perf list --details power*

List of pre-defined events (to be used in -e or -M):

  power/energy-cores/                                [Kernel PMU event]
  power/energy-pkg/                                  [Kernel PMU event]
  power/energy-psys/                                 [Kernel PMU event]

[output omitted]
```

Il contatore di performance `power/energy-cores/` fa parte dell'interfaccia Intel RAPL, basato su un registro MSR della CPU chiamato `MSR_PP0_ENERGY_STATUS`.
Gli altri due sono misurazioni di potenza relative al pacchetto (core e componenti uncore) e all'intero System on Chip; quest'ultimo è disponibile a partire dall'architettura Skylake.

Eseguiamo il nostro programma Python chiedendo a `perf` di raccogliere le metriche durante l'esecuzione:

```bash
# perf stat -ae power/energy-cores/,power/energy-pkg/,power/energy-psys/ python3 /tmp/prime.py
Prime = 15485863

 Performance counter stats for 'system wide':

            695.00 Joules power/energy-cores/                                                   
            930.12 Joules power/energy-pkg/                                                     
           1855.48 Joules power/energy-psys/                                                    

      61.362063830 seconds time elapsed
```
## 🚀 Possiamo fare di meglio

Per un confronto di prestazioni, verifichiamo lo stesso algoritmo scritto in Rust:

```Rust
fn is_prime(n: u64) -> bool {
    let sqrt_n = (n as f64).sqrt() as u64;
    for j in (3..=sqrt_n).step_by(2) {
        if n % j == 0 {
            return false;
        }
    }
    true
}

fn main() {
    let mut n = 2;
    let mut i = 3;

    while n < 1_000_000 {
        i += 2;
        if is_prime(i) {
            n += 1;
        }
    }
    println!("Prime = {}", i);
}
```

Nota: abbiamo semplicemente tradotto il codice Python, senza prestare alcuna attenzione all'ottimizzazione.

```bash
$ cargo build --release
   Compiling prime1m v0.1.0 (/home/andrea/projects/prove/prime1m)
    Finished `release` profile [optimized] target(s) in 0.12s

# perf stat -ae power/energy-cores/,power/energy-pkg/,power/energy-psys/ ./target/release/prime1m
Prime = 15485863

 Performance counter stats for 'system wide':

             24.46 Joules power/energy-cores/                                                   
             36.17 Joules power/energy-pkg/                                                     
             82.12 Joules power/energy-psys/                                                    

       2.987509303 seconds time elapsed
```

Come previsto, a parità di output, il programma compilato è circa ~20 volte più veloce e consuma meno risorse ed energia. Sembra interessante!

## 📚 Approfondimenti

RAPL (Running Average Power Limit) è una funzionalità hardware introdotta da Intel per facilitare la gestione energetica; l'interfaccia RAPL è trattata nella Sezione 14.9 del Manuale Intel Volume 3. 
Se volete saperne di più su questo framework, vi consiglio anche [questo articolo di ricerca](https://dl.acm.org/doi/10.1145/3177754).

Lo strumento `perf` può fare molto di più che leggere le metriche di potenza dal kernel. Se volete vedere alcuni esempi, visitate l'onnipresente sito web di [Brendan Gregg](https://www.brendangregg.com/perf.html).

Buon divertimento e happy green computing!
