---
layout: post
title: "Primi passi con il Linux Test Project"
description: "Come viene testato il Kernel Linux, una syscall alla volta"
categories: linux
tags: [linux, sysadmin, opensuse, test, kernel, syscalls]
author: Andrea Manzini
date: 2024-02-10
---

## 🕵️ Introduzione

Il [Linux Test Project](https://github.com/linux-test-project/ltp) (LTP) è un progetto congiunto avviato anni fa da SGI, OSDL e Bull, sviluppato e oggi mantenuto da IBM, Cisco, Fujitsu, SUSE, Red Hat, Oracle e molti altri. L'obiettivo del progetto è fornire alla community open source test che convalidino l'affidabilità, la robustezza e la stabilità di Linux. 

In questi giorni sto esplorando il progetto, quindi con questo articolo voglio mostrare passo dopo passo come configurarlo, come vengono effettivamente scritti i test e fornirvi una guida *rapida ed essenziale* per scrivere il vostro primo test.

## 🧰 Cominciamo

NOTA: Poiché alcuni test modificano le impostazioni del sistema operativo, se avete intenzione di eseguire l'intera suite di test è consigliabile mantenere pulita la vostra workstation e configurare un ambiente separato, come un PC di riserva o una macchina virtuale di sviluppo. 

La prima cosa da fare è installare gli strumenti di sviluppo e clonare la repository:

```bash
# zypper in -t pattern devel_basis 
or 
# zypper install gcc git make pkg-config autoconf automake bison flex m4 linux-glibc-devel glibc-devel

$ git clone https://github.com/linux-test-project/ltp.git && cd ltp
$ make autotools 
$ ./configure
[...omitted output...]
```

Ora potete continuare compilando ed eseguendo un singolo test oppure compilando e installando l'intera suite di test. Facciamo un piccolo passo alla volta:

## ⚗️ Un test di esempio

Se si desidera eseguire solo un singolo test, in realtà non è necessario compilare l'intero progetto LTP. Scegliamo un test di esempio per la [syscall `open()`](https://man7.org/linux/man-pages/man2/open.2.html). Per trovare questo test specifico:

```bash
$ cd testcases/kernel/syscalls/open
$ cat open03.c
```

### Cosa c'è dentro? ⁉️

{{< highlight C "linenos=table">}}
// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) Linux Test Project, 2001-2024
 * Copyright (c) 2000 Silicon Graphics, Inc.  All Rights Reserved.
 */

/*\
 * [Description]
 *
 * Testcase to check open() with O_RDWR | O_CREAT.
 */

#include "tst_test.h"

#define TEST_FILE "testfile"

static void verify_open(void)
{
        TST_EXP_FD(open(TEST_FILE, O_RDWR | O_CREAT, 0700));
        SAFE_CLOSE(TST_RET);
        SAFE_UNLINK(TEST_FILE);
}

static struct tst_test test = {
        .needs_tmpdir = 1,
        .test_all = verify_open,
};
{{< / highlight >}}

Questo test è piuttosto semplice, poiché il codice effettivo è inferiore a 10 righe. Ecco una breve panoramica riga per riga:

 - 1-12: commenti standard, licenza e intestazione della documentazione. Questo progetto ha più di 20 anni di storia!
 - 13: inclusione dell'header obbligatorio della libreria LTP
 - 15: un nome di file di esempio che proveremo a creare chiamando la syscall `open()`
 - 17-19: la funzione di test vera e propria: utilizzando le macro fornite dal framework, invia al kernel una chiamata di sistema `open()` e si assicura che l'operazione vada a buon fine; se per qualsiasi motivo la syscall dovesse restituire un errore, questo viene segnalato automaticamente e il risultato del test viene contrassegnato come *fallito* (failed). In ogni caso, il valore restituito viene memorizzato nella variabile `TST_RET`
 - 20-22: le macro `SAFE_*` ci consentono di chiudere ed eliminare il file appena aperto in modo pulito
 - 24-27: definizione dei metadati del test: di quali opzioni ha bisogno per essere eseguito e qual è la funzione che il framework eseguirà per noi. Il framework LTP cercherà questa struttura e utilizzerà le informazioni contenute al suo interno. Se siete curiosi di conoscere tutte le opzioni disponibili, potete trovare una buona [descrizione qui](https://ltp-core.readthedocs.io/en/latest/#customize-test-options), ma trattandosi di un argomento molto vasto, merita un post dedicato in futuro

Il [Linux Test Project](https://github.com/linux-test-project/ltp), così como lo stesso Kernel Linux, fa un uso massiccio di macro C, al fine di mantenere i test puliti, manutenibili e leggibili. Ovviamente tutte le macro e le funzioni di libreria sono documentate e spiegate nella documentazione del progetto.

Per un riferimento delle syscall, basta consultare le **pagine man** del sistema. Un piccolo consiglio: è raccomandabile clonare il [repository man ufficiale a monte (upstream)](git://git.kernel.org/pub/scm/docs/man-pages/man-pages.git) perché a volte le pagine man distribuite con le distribuzioni possono essere un po' vecchie.

## 👟 Come eseguire il test

Grazie alla configurazione del build system, possiamo semplicemente compilare con `make` il nostro singolo test ed eseguire l'eseguibile standalone. LTP aggiungerà molte informazioni utili al nostro piccolo programma:

```bash
$ make open03
[... compiler messages omitted...]
$ ./open03
tst_test.c:1741: TINFO: LTP version: 20240129
tst_test.c:1625: TINFO: Timeout per run is 0h 00m 30s
open03.c:19: TPASS: open(TEST_FILE, O_RDWR | O_CREAT, 0700) returned fd 3

Summary:
passed   1
failed   0
broken   0
skipped  0
warnings 0
```

L'eseguibile compilato accetta anche alcune opzioni, sempre grazie al framework LTP:

```bash
$ ./open03 -h
Environment Variables
---------------------
KCONFIG_PATH         Specify kernel config file
KCONFIG_SKIP_CHECK   Skip kernel config check if variable set (not set by default)
LTPROOT              Prefix for installed LTP (default: /opt/ltp)
LTP_COLORIZE_OUTPUT  Force colorized output behaviour (y/1 always, n/0: never)
LTP_DEV              Path to the block device to be used (for .needs_device)
LTP_DEV_FS_TYPE      Filesystem used for testing (default: ext2)
LTP_SINGLE_FS_TYPE   Testing only - specifies filesystem instead all supported (for .all_filesystems)
LTP_TIMEOUT_MUL      Timeout multiplier (must be a number >=1)
LTP_RUNTIME_MUL      Runtime multiplier (must be a number >=1)
LTP_VIRT_OVERRIDE    Overrides virtual machine detection (values: ""|kvm|microsoft|xen|zvm)
TMPDIR               Base directory for template directory (for .needs_tmpdir, default: /tmp)

Timeout and runtime
-------------------
Test timeout (not including runtime) 0h 0m 30s

Options
-------
-h       Prints this help
-i n     Execute test n times
-I x     Execute test for n seconds
-D       Prints debug information
-V       Prints LTP version
-C ARG   Run child process with ARG arguments (used internally)
```

potete anche controllare il vostro codice sorgente rispetto alle best practice del progetto:

```bash
$ make check-open03
```
Riceverete suggerimenti ed errori sulla qualità del codice, la formattazione e le possibili deviazioni dagli standard di programmazione del progetto.

## 🗿 Hello, nuovo test 

Quindi, se volete scrivere un nuovo test per LTP, potete semplicemente scegliere una sottocartella in `testcases/kernel/` e creare un nuovo file `.c` usando un template come questo:

{{< highlight C "linenos=table">}}
#include <tst_test.h>

static void setup(void) {
        // your setup code goes here
        tst_res(TINFO, "example setup");
}

static void cleanup(void) {
        // your cleanup code goes here
        tst_res(TINFO, "example cleanup");
}

static void run(void) {
        // your test code goes here
        tst_res(TPASS, "Doing hardly anything is easy");
}

static struct tst_test test = {
        .test_all = run,
        .setup = setup,
        .cleanup = cleanup,
};
{{< / highlight >}}

In questo esempio è importante notare che le funzioni `setup()` e `cleanup()` servono a creare/disporre le risorse del test (come buffer, file, socket, processi figli e così via) e vengono eseguite una sola volta, mentre `run()` è il codice di test vero e proprio e può essere ripetuto molte volte.

Dopo aver salvato il codice sorgente con un nome del tipo `mynewtest01.c`, basta eseguire:

```bash
$ make mynewtest01
CC testcases/kernel/syscalls/open/mynewtest01

$ ls -l mynewtest*
-rwxr-xr-x 1 andrea andrea 738064 Feb 10 11:46 mynewtest01
-rw-r--r-- 1 andrea andrea    475 Feb 10 11:46 mynewtest01.c

$ ./mynewtest01
tst_test.c:1741: TINFO: LTP version: 20240129
tst_test.c:1625: TINFO: Timeout per run is 0h 00m 30s
mynewtest01.c:5: TINFO: example setup
mynewtest01.c:15: TPASS: Doing hardly anything is easy
mynewtest01.c:10: TINFO: example cleanup

Summary:
passed   1
failed   0
broken   0
skipped  0
warnings 0
```

Non fa ancora nulla ma sembra funzionare; ora non vi resta che implementare la logica del test vero e proprio.

Una volta terminato e testato, se volete che il nuovo test venga eseguito come parte della suite, dovete aggiungerlo in una delle sottocartelle `runtest`, dove ogni file di testo definisce un gruppo di test (ovvero una test suite). 

## ✅ Conclusioni

Se siete interessati al progetto, consultate la [Wiki del progetto](https://github.com/linux-test-project/ltp/wiki) per ulteriore documentazione e per le linee guida di scrittura (Writing Guidelines); potete anche iscrivervi alla [Mailing List di LTP](https://lists.linux.it/listinfo/ltp). Buon divertimento!
