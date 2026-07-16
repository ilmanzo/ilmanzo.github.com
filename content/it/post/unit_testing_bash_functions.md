---
layout: post
title: "Utilizzo dei container per lo unit testing di funzioni bash"
description: "Come creare un ambiente isolato per testare in sicurezza i tuoi script bash"
categories: programming
tags: [programming, bash, testing, test, container, podman, 'unit testing']
author: Andrea Manzini
date: 2023-08-17
---

## Intro

Lo unit testing di funzioni Bash comporta il processo di verifica sistematica della correttezza e dell'affidabilità delle singole funzioni all'interno di uno script Bash. Sebbene Bash sia utilizzato principalmente per lo scripting e l'automazione, è importante garantire che le funzioni all'interno dei tuoi script funzionino come previsto, specialmente quando gli script diventano più complessi. Lo unit testing in Bash può aiutare a individuare bug e prevenire comportamenti imprevisti.

## Fixing bugs

Mentre lavoravo alla correzione di un bug in uno script di shell interno, volevo aggiungere alcuni unit test per garantirne la correttezza. Dopo una rapida ricerca, ho trovato questo ["framework" a file singolo](https://github.com/rafritts/bunit) (grazie, Ryan) che fornisce asserzioni in stile *xUnit*. Possiamo quindi usarlo come punto di partenza.

Il problema principale dello script sotto test è che contiene funzioni che manipolano direttamente il filesystem dell'host, quindi può essere difficile estrarre e fare il *mocking* di queste interazioni per un test appropriato.

Ho deciso quindi di utilizzare un semplice container per eseguire lo script in un ambiente isolato. Già che ci siamo, non servono demoni, basta usare rootless podman. Questo è lo script principale, l'unico da eseguire e che avvia tutte le suite di test:

{{< highlight bash >}}
#!/bin/bash

# Questo script eseguirà gli unit test per le funzioni nel file "mylib".
# i test vengono eseguiti in un container per garantire l'isolamento dal sistema host

if [ "$EUID" -eq 0 ]
  then echo "Please don't run this script as root"
  exit
fi
# opzionalmente, puoi usare immagini di distribuzioni diverse qui
podman run -v ..:/mnt registry.opensuse.org/opensuse/leap:latest bash /mnt/unit_tests/test_mylib.ut
{{</ highlight >}}

## Eseguire i test senza danneggiare il sistema

All'interno dello stesso `test_mylib.ut`, che non è eseguibile, ho aggiunto un altro controllo di sicurezza, in modo che l'utente sia consapevole che lo script di test può essere eseguito in sicurezza solo all'interno di un container:

{{< highlight bash >}}
#!/bin/bash

source "/mnt/unit_tests/bunit.shl"
source "/mnt/mylib.sh"

function testSetup() {
  [...]
}

function test_single() {
    [...]
    assertEquals 0 $?
}

function test_duplicate() {
    [...]
    local output=$( ... )
    assertNull "$output"
}

## controllo di sicurezza
if [ "$container" != "podman" ]; then
  echo "ERROR: this is script is not intended to be run directly."
  echo "Don't run this script standalone/outside a container, it will break your system"
  exit 0
else
  echo "Starting test..."
  runUnitTests
fi
{{</ highlight >}}

## Outro

In conclusione, lo unit testing delle funzioni Bash è una pratica essenziale per garantire l'affidabilità, la correttezza e la manutenibilità dei vostri script. Creando suite di test complete e impiegando framework di test, gli sviluppatori possono individuare precocemente i bug, migliorare la qualità del codice e apportare modifiche ai propri script con sicurezza. Sebbene il test degli script Bash possa richiedere considerazioni aggiuntive a causa delle loro interazioni con risorse esterne, i vantaggi dello unit testing superano di gran lunga le sfide, portando a soluzioni di scripting più robuste e prevedibili.
