---
layout: post
title: "Refactoring dei D Koans con la metaprogrammazione"
description: "Come la metaprogrammazione ha aiutato a creare un'esperienza di test più pulita per i D Koans"
categories: programming
tags: [D, dlang, programming, learning, metaprogramming, test, koans]
author: Andrea Manzini
date: 2025-05-21
---

## 💡 Il problema


Benvenuti di nuovo! È passato un bel po' di tempo dalle mie [ultime divagazioni](https://ilmanzo.github.io/post/fileinput-for-d-programming-language/) sul [linguaggio di programmazione D (Dlang)](https://dlang.org/)!

Questo post nasce da una necessità. Un mio vecchio progetto, i [D Koans](https://github.com/ilmanzo/DLangKoans), utilizzava una libreria esterna per semplificare gli unit test, che costituiscono più o meno il cuore dell'intero progetto. Sfortunatamente, la libreria ha iniziato a mostrare [alcuni avvisi di deprecazione (deprecation warnings)](https://github.com/linkrope/dunit/issues/36) quando compilata con le versioni recenti di D.

Poiché il linguaggio D possiede già un framework interno di [unit testing](https://dlang.org/spec/unittest.html), ho pensato che sarebbe stato bello rimuovere l'unica dipendenza e fare affidamento solo sulla libreria standard. Inizialmente, con una ricerca e sostituzione globale, sono riuscito a convertire tutti i test in blocchi `unittest`.

![dlang_meme](/img/dlang_explain_meme.jpg)

## 😫 I traceback dello stack sono brutti

L'esecuzione di questi test ha presentato un'altra sfida. L'utilizzo diretto degli unit test standard avrebbe messo gli utenti di fronte a messaggi di errore fitti e complessi, come questo:

```
core.exception.AssertError@koans/alias_this.d(39): unittest failure
----------------
??:? _d_unittestp [0x4bb84d]
koans/alias_this.d:39 void koans.alias_this.__unittest_L34_C1() [0x48b731]
??:? void koans.alias_this.__modtest() [0x48b788]
??:? int core.runtime.runModuleUnitTests().__foreachbody_L603_C5(object.ModuleInfo*) [0x4ccdb2]
??:? int object.ModuleInfo.opApply(scope int delegate(object.ModuleInfo*)).__lambda_L2467_C13(immutable(object.ModuleInfo*)) [0x4b2867]
??:? int rt.minfo.moduleinfos_apply(scope int delegate(immutable(object.ModuleInfo*))).__foreachbody_L582_C5(ref rt.sections_elf_shared.DSO) [0x4c1dc7]
??:? int rt.sections_elf_shared.DSO.opApply(scope int delegate(ref rt.sections_elf_shared.DSO)) [0x4c2149]
??:? int rt.minfo.moduleinfos_apply(scope int delegate(immutable(object.ModuleInfo*))) [0x4c1d55]
??:? int object.ModuleInfo.opApply(scope int delegate(object.ModuleInfo*)) [0x4b2839]
??:? runModuleUnitTests [0x4ccbe7]
??:? void rt.dmain2._d_run_main2(char[][], ulong, extern (C) int function(char[][])*).runAll() [0x4c00dc]
??:? void rt.dmain2._d_run_main2(char[][], ulong, extern (C) int function(char[][])*).tryExec(scope void delegate()) [0x4c0069]
??:? _d_run_main2 [0x4bffd2]
??:? _d_run_main [0x4bfdbb]
/usr/include/dlang/dmd/core/internal/entrypoint.d:29 main [0x484a69]
??:? [0x7f94bda2b12d]
??:? __libc_start_main [0x7f94bda2b1f8]
<unknown dir>/<unknown file>:115 _start [0x484884]
core.exception.AssertError@koans/arrays.d(8): unittest failure
```

il che è tutt'altro che ideale per un principiante; inoltre, tutti gli unit test vengono eseguiti in parallelo, quindi si otterrebbe un muro di testo incomprensibile. 

## 🦸 La metaprogrammazione in aiuto

La soluzione è *raccogliere* tutti gli unit test ed eseguirli manualmente in un ciclo `foreach`!
Questo porta a un altro problema: il progetto è composto di molti moduli, simili a *\"esercizi\"* progressivi che lo studente deve completare per imparare. Come facciamo a enumerare tutti i moduli, in un ordine stabilito, e fare in modo che il programma principale li importi e possa chiamare le loro funzioni? Permettetemi di presentarvi la **metaprogrammazione** :)

Dato che tutti gli esercizi si trovano in una directory, è facile raggrupparli in un singolo [modulo package (`package module`)](https://dlang.org/spec/module.html#package-module):

```bash
$ tree   
.
├── dscanner.ini
├── dub.json
├── koans
│   ├── alias_this.d
│   ├── arrays.d
│   ├── associative_arrays.d
│   ├── basics.d
│   ├── bitwise_operators.d
│   ├── chars.d
│   ├── c_interop.d
│   ├── classes.d
│   ├── concurrency.d
│   ├── ctfe.d
│   ├── delegates.d
│   ├── enums.d
│   ├── exceptions.d
│   ├── files.d
│   ├── foreach_loop.d
│   ├── function_parameters.d
│   ├── helpers.d
│   ├── lambda_syntax.d
│   ├── mixins.d
│   ├── numbers.d
│   ├── operator_overloading.d
│   ├── package.d  <--------------- QUESTO
│   ├── pointers.d
│   ├── properties.d
│   ├── strings.d
│   ├── structs.d
│   ├── templates.d
│   ├── traits.d
│   ├── tuples.d
│   └── unions.d
├── learn.d
├── README.md
└── scripts
    ├── runner_linux.sh
    └── runner_osx.sh
```

Il nostro `package.d` è semplice:

{{< highlight D "linenos=true">}}
// koans/package.d 
module koans;

static immutable koansModules = [
    "basics", "numbers", "chars", "strings",
    // ... enumera tutti i moduli degli esercizi
];

static foreach (m; koansModules)
    mixin("public static import koans." ~ m ~ ";");
{{</ highlight >}}

invece di importare tutti i moduli singolarmente, usiamo un ciclo per creare *a tempo di compilazione* (compile time) le istruzioni di importazione. In questo modo, il programma principale deve solo importare `import koans` come pacchetto completo.

nota: riutilizzeremo lo stesso elenco di moduli nel programma principale (`main`):

## ⚙️ Un test runner personalizzato

{{< highlight D "linenos=true">}}
// learn.d
module learn;

import core.runtime;
import std.stdio;
import koans;
static import core.exception;

shared static this()
{
    // Sovrascrive il test runner predefinito per non fare nulla.
    // Dopodiché, verrà chiamato il "main".
    Runtime.moduleUnitTester = { return true; };
}

void main()
{
    writeln("Starting your journey to enlightenment...");
    writeln("You will be asked to fill in the blanks in the koans.");
    writeln("Ensure to run 'dub --build=unittest' to run the tests.");
    static foreach (m; koans.koansModules)
    {
        mixin("static import koans." ~ m ~ ";");
        foreach (t; __traits(getUnitTests, mixin("koans." ~ m)))
        {
            try t();
            catch (core.exception.AssertError e)
            {
                writeln("Meditate more on ", e.file, " at line ", e.line);
                return;
            }
        }
    }
    writeln("You have reached the end of your journey");
}
{{</ highlight >}}

Le parti importanti sono:

- righe 9-14: è necessario sovrascrivere la funzione predefinita `Runtime.moduleUnitTester`. Questo permetterà al nostro `main` di essere eseguito anche quando il programma viene compilato con il flag `--unittest`.
- riga 21: iteriamo su ogni modulo, riutilizzando lo stesso array di stringhe definito in precedenza in `package.d`.
- riga 23: costruiamo un'istruzione di importazione con ambito (scoped import) con il nome del modulo, preceduto dal nome del pacchetto (es. `koans.basics`).
- riga 24: usiamo i [traits](https://dlang.org/spec/traits.html) per scorrere tutti gli unit test di quel modulo, eseguendo l'unit test (che è incapsulato come una funzione) all'interno di un blocco `try-catch` per catturare l'errore `AssertError`.
- riga 29: se l'unit test fallisce, forniamo all'utente istruzioni su quale riga di quale file deve essere modificata e il programma termina.

![dlang](/img/DLang.jpg)
(immancabile immagine accattivante generata dall'IA)

## ✅ Conclusioni

Il mio progetto ora non dipende da nessun'altra libreria e sarà estremamente semplice aggiungere nuovi test: basta seguire le convenzioni del linguaggio e creare un nuovo file con gli unit test, per poi scriverne il nome nella posizione corretta dell'array.

Spero che questo esempio pratico delle capacità di D sia stato interessante. E, cosa più importante, vi ha incuriosito abbastanza da voler approfondire la conoscenza del linguaggio D?

Avete mai usato la metaprogrammazione di D per compiti simili? I feedback sono i benvenuti!
