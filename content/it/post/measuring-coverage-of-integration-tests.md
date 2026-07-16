---
layout: post
title: "Quanto codice stai testando? (1)"
description: "Misurare la copertura dei test di integrazione"
categories: [programming, testing]
tags: [testing, tutorial, coverage, go, golang, qa]
series: ["How much code are you testing?"]
series_order: 1
author: Andrea Manzini
date: 2025-02-23
---

## ☂️ Introduzione

Quando il vostro codice include una suite di unit test, la [copertura del codice (code coverage)](https://en.wikipedia.org/wiki/Code_coverage) è una metrica importante per misurare l'efficacia dei test ed è piuttosto facile da ottenere; ci sono [moltissimi strumenti in circolazione](https://www.browserstack.com/guide/code-coverage-tools).

![metrics](/img/pexels-n-voitkevich-6120217.jpg)
Crediti immagine: [Nataliya Vaitkevich](https://www.pexels.com/it-it/@n-voitkevich/)

D'altra parte, spesso abbiamo anche bisogno di eseguire test di integrazione o E2E (end-to-end), poiché nei nostri flussi di QA eseguiamo principalmente applicazioni reali piuttosto che singole funzioni isolate.

Iniziamo con un caso d'uso di base e prepariamo un semplice programma su misura per questo scopo.

Supponiamo di voler testare un semplice programma che stampa `"Hello, World!"` con alcuni argomenti opzionali sulla riga di comando (potete trovare il codice sorgente in fondo 👇):

```
$ ./hello --help   
Usage of ./hello:
  -count int
    	number of times to repeat (default 1)
  -header
    	print also a fancy header
  -name string
    	your name for greeting (default "World")
  -upper
    	convert to uppercase
```

## 🚦 Rosso, Verde, Refactoring

Useremo il framework `pytest`, ma [qualsiasi altro](https://open.qa/) andrebbe altrettanto bene. Come primo passo, scriviamo un test *fallimentare* (rosso):

```python
# test_hello.py

from subprocess import run

def smoke(capfd):
    run(["./hello"])
    out, err = capfd.readouterr()
    assert out == ""
```

esecuzione semplice:

```bash
$ pytest           
============================ test session starts =============================
platform linux -- Python 3.11.11, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/projects/test
collected 1 item                                                                     

test_hello.py F                                                        [100%]

================================== FAILURES ==================================
_________________________________ test_hello _________________________________

capfd = <_pytest.capture.CaptureFixture object at 0x7f3824e41650>

    def test_smoke(capfd):
        run(["./hello"])
        out, err = capfd.readouterr()
>       assert out == ""
E       AssertionError: assert 'Hello, World!\n' == ''
E         
E         + Hello, World!

test_hello.py:6: AssertionError
========================== short test summary info ===========================
FAILED test_hello.py::test_smoke - AssertionError: assert 'Hello, World!\n' == ''
============================= 1 failed in 0.02s ==============================
```

Ebbene sì... Dobbiamo verificare l'output corretto. Niente di più semplice:

```python
# test_hello.py

from subprocess import run

def test_smoke(capfd):
    run(["./hello"])
    out, err = capfd.readouterr()
    assert out == "Hello, World!\n"

```

```bash
$ pytest
============================ test session starts =============================
platform linux -- Python 3.11.11, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/projects/test
collected 1 item                                                                     

test_hello.py .                                                        [100%]

============================= 1 passed in 0.01s ==============================
```

## 📣 Dillo più forte

Siamo degli ingegneri QA fantastici e in gamba, vero? 😎 Quindi, osservando l'help della riga di comando del programma, decidiamo di scrivere un secondo test per provare la funzionalità del testo in *maiuscolo* (uppercase):

```python
# test_hello.py

from subprocess import run

def test_smoke(capfd):
    run(["./hello"])
    out, err = capfd.readouterr()
    assert out == "Hello, World!\n"

def test_uppercase(capfd):
    run(["./hello", "-upper"])
    out, err = capfd.readouterr()
    assert out == "HELLO, WORLD!\n"

```

```bash
$ pytest            
============================== test session starts ===============================
platform linux -- Python 3.11.11, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/projects/test
collected 2 items                                                                    

test_hello.py ..                                                           [100%]

=============================== 2 passed in 0.02s ================================
```

🎉 🎉 Abbiamo raddoppiato la copertura dei test, festeggiamo! 🎉 🎉 Il nostro lavoro sembra finito...

Aspettate... In realtà, come si fa a dire quando i nostri test sono **abbastanza buoni**? *Quanto* del codice del programma state effettivamente eseguendo? I nostri test evitano o trascurano qualche funzionalità chiave?

## 🌡️ Introduciamo lo strumento di misura

Per ogni esecuzione del test, dobbiamo misurare il rapporto tra il codice eseguito e il codice totale del programma. Questo è un argomento complesso e dipende principalmente da come è costruito il programma, ma come primo passo possiamo utilizzare una funzionalità che Go ha introdotto un paio di anni fa, a partire dalla [versione 1.20](https://go.dev/blog/integration-test-coverage).

Quindi, ricompiliamo il programma con le informazioni di copertura nel binario:

```bash
$ go build -cover hello.go
```

Una volta compilato, il programma ci dà un indizio sul fatto che qualcosa è cambiato:

```bash
$ ./hello 
warning: GOCOVERDIR not set, no coverage data emitted
Hello, World!
```

Il compilatore Go ha *strumentato* il programma, e ora dobbiamo fornirgli un percorso in cui memorizzare i dati di copertura raccolti.
Quindi, prepariamo un semplice script che configurerà l'ambiente ed eseguirà anche la nostra suite di test:

```bash
$ cat cov_test.sh 
#!/bin/sh
rm -rf covdatafiles
mkdir covdatafiles
rm hello && go build -cover hello.go
GOCOVERDIR=covdatafiles pytest
```

L'esecuzione apparentemente non è cambiata:
```bash
$ ./cov_test.sh 
============================== test session starts ===============================
platform linux -- Python 3.11.11, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/projects/test
collected 2 items                                                                    

test_hello.py ..                                                           [100%]

=============================== 2 passed in 0.02s ================================
```

ma ora abbiamo dei dati in una nuova sottocartella:

```bash
$ ls covdatafiles 
covcounters.6d07efc23254e1696fe8a1428981e28e.13877.1740324625565161919
covcounters.6d07efc23254e1696fe8a1428981e28e.13882.1740324625569223562
covmeta.6d07efc23254e1696fe8a1428981e28e
```

questi file sono destinati a essere elaborati da un altro strumento:

```bash
$ go tool covdata percent -i covdatafiles 
	command-line-arguments		coverage: 85.7% of statements
```

## 🐤 Un altro piccolo passo

aggiungiamo un altro test e vediamo se la nostra copertura aumenta:

```python
from subprocess import run

def test_smoke(capfd):
    run(["./hello"])
    out, err = capfd.readouterr()
    assert out == "Hello, World!\n"

def test_uppercase(capfd):
    run(["./hello", "-upper"])
    out, err = capfd.readouterr()
    assert out == "HELLO, WORLD!\n"

def test_header(capfd):
    run(["./hello", "-header"])
    out, err = capfd.readouterr()
    assert out == "-------------\nHello, World!\n"
```

## 🚀 Evviva!

```bash
$ go tool covdata percent -i covdatafiles 
	command-line-arguments		coverage: 92.9% of statements
```

Abbiamo fatto un passo avanti e possiamo tranquillamente affermare che **i nostri test sono migliori di prima**.

Già che ci siamo, integriamo l'[output della copertura](https://pkg.go.dev/cmd/covdata) nel nostro script di test:

```bash
$ cat cov_test.sh 
#!/bin/sh
rm -rf covdatafiles
mkdir covdatafiles
rm hello && go build -cover hello.go
GOCOVERDIR=covdatafiles pytest
go tool covdata percent -i covdatafiles
```


## 🔎 Usa la forza del sorgente, Luke

Ora una domanda per il lettore; guardando il codice sorgente del programma:

{{< highlight go >}}
package main

import (
	"flag"
	"fmt"
	"strings"
)

func main() {
	name := flag.String("name", "World", "your name for greeting")
	count := flag.Int("count", 1, "number of times to repeat")
	isUpper := flag.Bool("upper", false, "convert to uppercase")
	addHeader := flag.Bool("header", false, "print also a fancy header")
	flag.Parse()
	message := fmt.Sprintf("Hello, %s!", *name)
	if *name == "Andrea" {
		message += " Welcome back!"
	}
	if *isUpper {
		message = strings.ToUpper(message)
	}
	if *addHeader {
		fmt.Println(strings.Repeat("-", len(message)))
	}
	for i := 0; i < *count; i++ {
		fmt.Println(message)
	}
}
{{</ highlight >}}

vi viene in mente un ultimo test da scrivere per raggiungere il 100% di copertura? 😉

Ottima notizia: possiamo avere un indizio visivo producendo un output HTML!
Dobbiamo solo aggiungere un altro paio di righe di post-elaborazione:

```bash
$ go tool covdata textfmt -i=covdatafiles -o=coverage.txt
$ go tool cover -html coverage.txt
```

![html coverage](/img/integration-coverage-html-screenshot.png)

Ebbene sì, ora è molto chiaro cosa ci stiamo perdendo :smile:

```python
def test_andrea(capfd):
    run(["./hello","-name","Andrea"])
    out, err = capfd.readouterr()
    assert out == "Hello, Andrea! Welcome back!\n"
```

## 🧪 Considerazioni finali

Grazie all'eccellente [strumentazione fornita da Go](https://go.dev/doc/build-cover), aggiungere informazioni di copertura ai binari compilati è semplicissimo e possiamo finalmente avere un'idea di quanto codice i nostri test stanno effettivamente sondando.

Sono sicuro che sia una metrica molto importante da avere, quindi possiamo pensare a dei modi per estendere questo concetto ad altri linguaggi e tecnologie.

aggiornamento: c'è un post di follow-up che potete leggere [qui](https://ilmanzo.github.io/it/post/measuring-test-coverage-on-binaries/)

Sentitevi liberi di lasciarmi commenti e feedback, buon hacking! :wave:
