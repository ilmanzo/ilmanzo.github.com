---
layout: post
title: "Quanto codice stai testando? (3)"
description: "Utilizzare Intel PIN per misurare la copertura dei test sui binari"
categories: [programming, testing]
tags: [testing, tutorial, linux, coverage, e2e, qa, tracing, scripting, C, C++, instrumentation]
series: ["How much code are you testing?"]
series_order: 3
author: Andrea Manzini
date: 2025-06-17

---

## ▶️ Intro: [Let Me Be](https://www.youtube.com/watch?v=mjPVv5ojKTo) 

Nel [post precedente](https://ilmanzo.github.io/it/post/measuring-test-coverage-on-binaries/) abbiamo continuato il nostro viaggio affrontando uno scenario più complesso, utilizzando un mix di `gdb` e `valgrind` per tracciare l'esecuzione di tutte le funzioni all'interno di un dato binario.

Questa volta reggetevi forte perché aumenteremo notevolmente la complessità. Ci immergeremo nell'analisi di basso livello ed esploreremo come utilizzare [Intel PIN](https://www.intel.com/content/www/us/en/developer/articles/tool/pin-a-dynamic-binary-instrumentation-tool.html), un potente framework di strumentazione dinamica per manipolare e ispezionare il codice eseguibile a runtime.

![probe](/img/pexels-furqan-khurshid-484332193-25655714.jpg)
(Foto di [FURQAN KHURSHID](https://www.pexels.com/photo/close-up-of-a-man-soldering-25655714/))

Iniziamo con un programma in C elementare, il cui comportamento varia a seconda degli argomenti passati sulla riga di comando:

## 🎯 Il target: [Gonna Make You Sweat](https://www.youtube.com/watch?v=LaTGrV58wec)

{{< highlight C >}}
#include <stdio.h>
#include <stdlib.h>

int add(int a, int b) { return a+b; }
int mul(int a, int b) { return a*b; }

int main(int argc, char **argv)
{
    if (argc < 3) {
        // must input 2 number args
        fprintf(stderr, "input 2 numbers for calc add or mul.\n");
        fprintf(stderr, "Usage) ./a.out 1 2\n");
        return -1;
    }

    int a = atoi(argv[1]);
    int b = atoi(argv[2]);

    if (a < b) {
        printf("the answer is a + b = %d\n", add(a, b));
    } else  {
        printf("the answer is a * b = %d\n", mul(a, b));
    }
  
    return 0;
}
{{< /highlight >}}

Compiliamolo, quindi, per usarlo come nostro banco di prova:

{{< highlight bash >}}
$ cc -g -gdwarf-4 main.c -o cov_sample
$ example/cov_sample 7 3
the answer is a * b = 21
$ example/cov_sample 2 5
the answer is a + b = 7
{{< /highlight >}}

Compiliamo con il flag `-g` per incorporare le informazioni di debug direttamente nell'eseguibile. Anche se questo non è strettamente necessario — Pin può funzionare anche con file di simboli di debug esterni — semplifica il nostro esempio.

## 📌 Uno strumento di tracciamento: [Surrender](https://www.youtube.com/watch?v=Uj_oZ48ccPc)

[Intel PIN](https://www.intel.com/content/www/us/en/developer/articles/tool/pin-a-dynamic-binary-instrumentation-tool.html) è un framework di strumentazione binaria dinamica per le architetture dei set di istruzioni IA-32 e x86-64 che consente la creazione di strumenti di analisi dinamica dei programmi. Pin è fornito e supportato da Intel, gratuitamente per qualsiasi tipo di utilizzo, secondo i termini della Intel Simplified Software License ([ISSL](https://software.intel.com/sites/landingpage/pintool/intel-simplified-software-license.txt)).
Tutto il codice sorgente contenuto nel kit di Pin, compresi script, codice di esempio e header, è disciplinato dalla [licenza MIT](https://software.intel.com/sites/landingpage/pintool/LICENSE-mit.txt).

Pin consente a uno strumento di inserire codice arbitrario (scritto in C o C++) in punti arbitrari dell'eseguibile. Il codice viene aggiunto dinamicamente mentre l'eseguibile è in esecuzione. Ciò rende anche possibile collegare Pin a un processo già in esecuzione.

Pin fornisce una ricca API che astrae le peculiarità del set di istruzioni sottostante e consente di passare al codice iniettato informazioni di contesto come il contenuto dei registri sotto forma di parametri. Pin salva e ripristina automaticamente i registri sovrascritti dal codice iniettato, in modo che l'applicazione continui a funzionare. È inoltre disponibile un accesso limitato ai simboli e alle informazioni di debug.

Senza ulteriori indugi, vediamo come si presenta un `pintool`:

{{< highlight cpp >}}
/* FuncTracer.cpp */
#include "pin.H"
#include <iostream>

// Questa funzione viene chiamata prima di ogni funzione nell'applicazione strumentata.
// Registra l'ID del processo, il nome dell'immagine e il nome della funzione.
VOID log_function_call(const char *img_name, const char *func_name)
{
    // ...
}

// Pin chiama questa funzione per ogni immagine caricata nello spazio di indirizzamento del processo.
// Un'immagine è un eseguibile o una libreria condivisa.
VOID ImageLoad(IMG img, VOID *v)
{
    // Iteriamo attraverso tutte le routine (funzioni) nell'immagine.
    for (SEC sec = IMG_SecHead(img); SEC_Valid(sec); sec = SEC_Next(sec))
    {
        for (RTN rtn = SEC_RtnHead(sec); RTN_Valid(rtn); rtn = RTN_Next(rtn))
        {
            std::stringstream ss;
            RTN_Open(rtn);
            ss << "[Image:" << IMG_Name(img) << "] [Function:" << RTN_Name(rtn) << "]\n" ;
            LOG(ss.str());
            // Per ogni routine, inseriamo una chiamata alla nostra funzione di analisi `log_function_call`.
            RTN_InsertCall(rtn, IPOINT_BEFORE, (AFUNPTR)log_function_call,
                           IARG_PTR, IMG_Name(img).c_str(),
                           IARG_PTR, RTN_Name(rtn).c_str(),
                           IARG_END);

            RTN_Close(rtn);
        }
    }
}

int main(int argc, char *argv[])
{
    PIN_InitSymbols();
    if (PIN_Init(argc, argv))
    {
        std::cerr << "PIN_Init failed" << std::endl;
        return 1;
    }
    // Registra la funzione da chiamare per ogni immagine caricata.
    IMG_AddInstrumentFunction(ImageLoad, 0);
    PIN_StartProgram();
    return 0;
}
{{< /highlight >}}

(questa è una versione ridotta, il programma completo è disponibile [sul mio repository](https://github.com/ilmanzo/BinaryCoverage)). Un grande ringraziamento a [@simotin13](https://github.com/simotin13) per aver fornito un prezioso punto di partenza!

Diamo un'occhiata alle istruzioni per compilare questo programma in una libreria `.so` condivisa, seguendo la [documentazione](https://software.intel.com/sites/landingpage/pintool/docs/98869/Pin/doc/html/index.html#BUILDINGTOOLS); se siete pigri o impazienti, troverete un comodo script [`build.sh`](https://github.com/ilmanzo/BinaryCoverage) e dei *Makefile* per compilare e collegare tutto correttamente.

## 💌 [Cosa viene registrato?](https://www.youtube.com/watch?v=HEXWRTEbj1I)

Ora possiamo eseguire pin, passandogli il nostro plugin, ed eseguire il target, in cui verrà iniettato il nostro codice di strumentazione.

{{< highlight bash >}}
export PIN_ROOT = <vostra directory di installazione di PIN>
$PIN_ROOT/pin -t ./obj-intel64/FuncTracer.so -- example/cov_sample 7 3
{{< /highlight >}}

Questo comando esegue il nostro binario di destinazione sotto il controllo di Pin, utilizzando la nostra nuova sonda personalizzata. Genera un file di log (`pintool.log`) con una traccia dettagliata. Diamo un'occhiata a un frammento dell'output:

```
Pin: pin-3.31-98869-fa6f126a8
Copyright 2002-2024 Intel Corporation.
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:_init]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:.plt]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:printf@plt]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:atoi@plt]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:fwrite@plt]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:_start]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:_dl_relocate_static_pie]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:deregister_tm_clones]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:register_tm_clones]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:__do_global_dtors_aux]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:frame_dummy]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:main]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:add]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:mul]
 [tid:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Function:_fini]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_call_libc_early_init.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:remove_slotinfo.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_close_worker.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_map_object_deps.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_fini.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:call_init.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_notify_new_object.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:add_name_to_object.isra.0.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:expand_dynamic_string_token.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_init_paths.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_map_object_from_fd.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_map_object.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_lookup_symbol_x.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:__minimal_realloc.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:_dl_new_object.cold]
 [tid:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Function:add_to_global_update.cold]
...
 [tid:10367] [PID:10367] [Image:/lib64/libc.so.6] [Called:pthread_mutex_unlock]
 [tid:10367] [PID:10367] [Image:/lib64/libc.so.6] [Called:__GI___pthread_mutex_unlock_usercnt]
 [tid:10367] [PID:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Called:_dl_call_fini]
 [tid:10367] [PID:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Called:__do_global_dtors_aux]
 [tid:10367] [PID:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Called:deregister_tm_clones]
 [tid:10367] [PID:10367] [Image:/home/andrea/CodeCoverage/example/cov_sample] [Called:_fini]
 [tid:10367] [PID:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Called:_dl_audit_objclose]
 [tid:10367] [PID:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Called:_dl_call_fini]
 [tid:10367] [PID:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Called:_dl_audit_objclose]
 [tid:10367] [PID:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Called:_dl_call_fini]
 [tid:10367] [PID:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Called:_dl_audit_objclose]
 [tid:10367] [PID:10367] [Image:/lib64/ld-linux-x86-64.so.2] [Called:_dl_audit_activity_nsid]
```

Poiché il log contiene sia l'elenco di tutte le funzioni del nostro binario sia le funzioni che sono state eseguite, è facile preparare uno script che emetta un report di copertura dall'aspetto accattivante.

```
==================================================
Image: /home/andrea/CodeCoverage/example/cov_sample
==================================================
  Functions Found:   15
  Functions Called:  12
  Coverage:          80.00%
--------------------------------------------------
  Called Functions:
    - .plt
    - __do_global_dtors_aux
    - _fini
    - _init
    - _start
    - atoi@plt
    - deregister_tm_clones
    - frame_dummy
    - main
    - add
    - printf@plt
    - register_tm_clones

  Uncalled Functions:
    - _dl_relocate_static_pie
    - mul
    - fwrite@plt
```

e con un po' di formattazione:

![report](/img/pintool_coverage_report.png)

ora abbiamo anche un'indicazione su dove sia meglio concentrare i nostri test, poiché alcune funzioni del programma non sono state chiamate.

Come miglioramento, potremmo preparare una "whitelist" di funzioni che sono *intrinseche* all'ambiente di esecuzione (come `main`, `_start` e così via) che possono essere escluse dal report.

## 🪩 [Andando oltre](https://www.youtube.com/watch?v=dQw4w9WgXcQ)

Sul [repository](https://github.com/ilmanzo/BinaryCoverage) potete trovare alcuni contenuti bonus:
- un programma Python che analizza il log e produce i report di copertura
- una comoda utilità `wrap.sh` che prende un binario, lo sostituisce con la chiamata di strumentazione appropriata e opzionalmente ne ripristina lo stato precedente.

Prossimo passo: invece di un target fittizio, "misureremo" i binari del sistema operativo, con automazione completa e senza necessità di ricompilazione. Never give (U) up 🙂‍↔️

p.s.
Se non ci avete fatto caso: come easter egg estivo, ogni sezione di questo post è una canzone Eurodance degli anni '90 🎧 Buon ascolto!
