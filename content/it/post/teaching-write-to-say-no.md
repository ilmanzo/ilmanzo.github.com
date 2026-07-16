---
title: "syscalln't 🚫"
description: "Insegnare a write() a dire di no: un'introduzione alle syscall e al fault injection, usando strace per far fallire una syscall a comando"
categories: ["linux", "programmazione"]
tags: ["linux", "kernel", "syscall", "strace", "python", "testing", "fault-injection"]
series: ["Syscall Fault Injection"]
series_order: 1
translationKey: teaching-write-to-say-no
author: Andrea Manzini
date: 2026-07-16
---

## 🤔 Cos'è una syscall, in pratica?

![Una Mini Cooper blu in equilibrio su due ruote durante uno spettacolo di stunt driving](/img/stunt-mini-cooper.jpg)
Crediti immagine: [Mike Norris](https://www.pexels.com/@miken/) via [Pexels](https://www.pexels.com/photo/exciting-car-stunt-show-at-saltburn-by-the-sea-34153581/)

Ogni volta che il tuo programma legge un file, scrive su un socket o alloca memoria, a un certo punto deve chiedere al kernel di farlo per davvero. Quella richiesta è una **syscall**: il confine preciso e ben definito in cui il codice in userspace passa nel kernel. `write()`, `read()`, `open()`, `mmap()` non sono semplici funzioni di libreria, sono l'intero vocabolario che il tuo programma ha a disposizione per parlare con il mondo esterno. Tutto il resto — da `fwrite` a `file.write()` in Python fino a `std::fs::File` in Rust — non è altro che un wrapper attorno a questa manciata di punti di ingresso del kernel.

Questo è fondamentale perché si tratta anche dell'*unico* punto in cui l'evento "qualcosa è andato storto nel mondo esterno" può effettivamente riflettersi sul tuo programma. Un disco pieno, una connessione di rete caduta o il raggiungimento del limite massimo di file descriptor non sono bug nel tuo codice: sono fatti legati all'ambiente circostante, e il kernel te li comunica in un solo modo, ovvero tramite una syscall che restituisce un errore. Il sistema non mente, ti sta semplicemente dicendo con onestà: "No, in questo momento non posso eseguire questa operazione". Se poi il tuo codice quel "no" lo *ascolta* davvero, beh, questa è tutta un'altra storia.

## 💥 Perché rompere le cose apposta?

Ecco la scomoda verità: il codice di gestione degli errori è, quasi sempre, il codice meno testato di tutta la codebase. Puoi scrivere un blocco `except OSError` perfettamente sensato attorno a una chiamata `write()`, ma se il disco non si riempie mai durante la fase di test, quel ramo di codice non verrà mai eseguito. Finisce così in produzione senza essere mai stato testato, ed entrerà in funzione per la prima volta proprio davanti a un utente reale, magari mettendo a rischio dati di produzione veri.

I fallimenti reali come "disco pieno" o "connessione interrotta" sono rari e scomodi da riprodurre a comando. **Il fault injection li rende economici e ripetibili.** Invece di sperare che il tuo codice di gestione degli errori funzioni, forzi tu stesso il fallimento, quando vuoi tu, e guardi cosa succede davvero.

Esiste uno strumento nativo nel kernel per farlo, `/sys/kernel/debug/fail_function`, ma richiede un kernel compilato con il supporto al fault injection per il debug, un'opzione che non è sempre abilitata di default. La buona notizia è che, per intercettare il confine delle syscall, esiste uno strumento con una barriera d'accesso molto più bassa e probabilmente già installato sul tuo sistema.

## 🧪 Ecco progress_log

Ogni tecnica di fault injection di questa serie ha il suo piccolo target costruito su misura, niente framework, niente codebase condivisa da studiare prima. Per questo esperimento con strace useremo qualcosa di estremamente semplice.

Ecco `progress_log`. Il programma elabora un batch di "elementi", registrando una riga per ciascuno di essi in un file di log man mano che procede. Si tratta del classico log di checkpoint di cui ogni job batch ha bisogno: se il processo muore a metà strada, saprai esattamente dove si è interrotto.

```python
#!/usr/bin/env python3
"""progress_log: record how far a (simulated) batch job got, one line per item.

If the job dies partway through, this log tells you exactly which item it was
on -- but only if a failed write() is caught instead of crashing silently.

Opened unbuffered (buffering=0) on purpose: Python's normal buffered file
objects can silently retry -- and succeed -- writing data on close(), even
after your code already caught and reported a write() failure for it.
Unbuffered means what you see here is exactly what happens at the syscall
level, no surprises.
"""
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <count> <path>", file=sys.stderr)
        return 1

    count = int(sys.argv[1])
    path = sys.argv[2]

    with open(path, "wb", buffering=0) as log:
        for item in range(1, count + 1):
            try:
                log.write(f"processed item {item}\n".encode())
                print(f"processed item {item}", flush=True)
            except OSError as e:
                print(f"stopped at item {item}: {e}", file=sys.stderr)
                return 1

    print(f"done: processed {count} items", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

La docstring mette in evidenza un dettaglio su cui vale la pena soffermarsi, anche in un articolo che mira alla massima semplicità. Una normale chiamata `open(path, "w")` bufferizza le scritture e, in caso di fallimento, Python non scarta necessariamente i byte non scritti. Una chiamata a `close()` successiva potrebbe infatti riuscire a scaricarli sul disco (flushing) comunque, *dopo* che il tuo codice ha già segnalato all'utente il fallimento dell'operazione. L'opzione `buffering=0` evita tutto questo alla radice: ogni singola operazione di scrittura si traduce immediatamente in una syscall, senza tentativi di riprovo o buffering nascosti. Si tratta di una trappola insidiosa da conoscere a prescindere dal fault injection, ma che in questo contesto assume un'importanza cruciale.

Il blocco `except OSError` rappresenta la nostra gestione degli errori, proprio quella parte di codice che normalmente resta ineseguita. Vediamo come farla scattare. Non è necessario alcun passaggio di compilazione:

```bash
$ chmod +x progress_log.py
$ ./progress_log.py 3 progress.log
processed item 1
processed item 2
processed item 3
done: processed 3 items
```

Tracciando l'esecuzione vediamo esattamente quello che ci aspettiamo: una chiamata `write()` sul file di log (fd 3) alternata a una `write()` su stdout (fd 1) per stampare il progresso.

```bash
$ strace -o baseline.strace.log -e trace=write ./progress_log.py 3 progress.log
$ cat baseline.strace.log
write(3, "processed item 1\n", 17)      = 17
write(1, "processed item 1\n", 17)      = 17
write(3, "processed item 2\n", 17)      = 17
write(1, "processed item 2\n", 17)      = 17
write(3, "processed item 3\n", 17)      = 17
write(1, "processed item 3\n", 17)      = 17
write(1, "done: processed 3 items\n", 24) = 24
+++ exited with 0 +++
```

## 🔍 Prima sorpresa: `strace --inject`

`strace` sa far fallire le syscall a comando fin dalla versione 4.15 (dicembre 2016, frutto di un lavoro guidato da Dmitry Levin nato come [progetto GSoC nel 2016](https://lists.strace.io/pipermail/strace-devel/2016-March/004649.html)). Nessuna patch al kernel richiesta:

```bash
$ strace -e trace=write -e inject=write:error=ENOSPC:when=3 ./prog
```

`when=3` significa "fai fallire la terza invocazione di questa syscall." Puntiamolo su `progress_log` e simuliamo un disco pieno alla terza `write()`:

```bash
$ strace -o naive.strace.log -e trace=write -e inject=write:error=ENOSPC:when=3 ./progress_log.py 5 progress.log
processed item 1
stopped at item 2: [Errno 28] No space left on device
```

Un attimo: l'esecuzione si è bloccata all'**elemento 2**, non al 3. Abbiamo forse sbagliato a contare? Il log di strace ci dice di no:

```bash
$ cat naive.strace.log
write(3, "processed item 1\n", 17)      = 17
write(1, "processed item 1\n", 17)      = 17
write(3, "processed item 2\n", 17)      = -1 ENOSPC (No space left on device) (INJECTED)
write(2, "stopped at item 2: [Errno 28] No"..., 54) = 54
+++ exited with 1 +++
```

Eccolo. `when=3` conta la **terza syscall `write()` che il processo fa, punto**, e anche il nostro messaggio di avanzamento su stdout (`processed item 1`, fd 1) è una `write()`. Al kernel non importa (e non può sapere) che la nostra intenzione era quella di colpire solo il file di log: il filtro `-e inject=write:...` intercetta la syscall `write()` su qualsiasi file descriptor. Questa è la classica assunzione che trae in inganno chiunque si avvicini al fault injection per la prima volta: il fallimento iniettato è reale, ma non avviene nel punto in cui ci si aspetterebbe.

## 🎯 Delimitare il raggio d'azione con `-P`

Per ovviare a questo problema, strace permette di restringere l'ambito del tracciamento — e di riflesso anche il contatore delle iniezioni — alle sole syscall che interessano un percorso specifico, utilizzando l'opzione `-P`. Nota bene: su strace 7.1, l'uso di un percorso **relativo** non produce alcun match, in modo del tutto silenzioso. Nessuna `write()` viene tracciata né iniettata, e il programma viene eseguito fino alla fine senza interruzioni, anche se la directory corrente corrisponde esattamente a quella del file.

```bash
$ strace -o relative.strace.log -e trace=write -P progress.log \
    -e inject=write:error=ENOSPC:when=3 ./progress_log.py 5 progress.log
processed item 1
processed item 2
processed item 3
processed item 4
processed item 5
done: processed 5 items
```

Usare il **percorso assoluto** risolve il problema:

```bash
$ strace -o scoped.strace.log -e trace=write -P "$(pwd)/progress.log" \
    -e inject=write:error=ENOSPC:when=3 ./progress_log.py 5 progress.log
processed item 1
processed item 2
stopped at item 3: [Errno 28] No space left on device
```

Ora solo le chiamate `write()` dirette al file descriptor del log vengono tracciate e conteggiate. Di conseguenza, il parametro `when=3` assume finalmente il significato desiderato:

```bash
$ cat scoped.strace.log
write(3, "processed item 1\n", 17)      = 17
write(3, "processed item 2\n", 17)      = 17
write(3, "processed item 3\n", 17)      = -1 ENOSPC (No space left on device) (INJECTED)
+++ exited with 1 +++

$ cat progress.log
processed item 1
processed item 2
```

I primi due elementi sono scritti correttamente sul disco, il terzo è stato rifiutato esattamente come avverrebbe in caso di disco pieno, e il nostro blocco `except OSError` ha intercettato l'errore in modo pulito. Nessun traceback Python spaventoso, nessun file corrotto silenziosamente, ma solo il messaggio di errore previsto per questa evenienza. Abbiamo appena visto il nostro ramo di gestione degli errori entrare in funzione per la prima volta.

## 🧫 Da guardare a verificare

Osservare l'output sul terminale è perfetto per un articolo di blog, ma è del tutto inutile all'interno di una suite di test. Il vero obiettivo, infatti, non è assistere passivamente al fallimento, bensì automatizzare la verifica che il codice risponda correttamente all'errore. Trasformiamo quindi il nostro esperimento manuale in un test automatizzato in grado di far fallire una build in caso di regressione:

```python
#!/usr/bin/env python3
"""Assert progress_log's unhappy path: a disk-full write() must be caught,
reported, and must not corrupt entries already on disk. This is the point
of the whole exercise -- not just watching the failure happen, asserting on it."""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def run_with_injected_fault(count, path, when):
    abs_path = os.path.abspath(path)
    return subprocess.run(
        [
            "strace", "-e", "trace=write", "-P", abs_path,
            "-e", f"inject=write:error=ENOSPC:when={when}",
            sys.executable, os.path.join(HERE, "progress_log.py"), str(count), path,
        ],
        capture_output=True, text=True,
    )


def main():
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "progress.log")
        result = run_with_injected_fault(count=5, path=path, when=3)

        assert result.returncode == 1, f"expected exit code 1, got {result.returncode}"
        assert "stopped at item 3" in result.stderr, (
            f"expected a failure message for item 3 on stderr, got: {result.stderr!r}"
        )
        assert "No space left on device" in result.stderr, (
            f"expected ENOSPC in the error message, got: {result.stderr!r}"
        )

        with open(path) as f:
            lines = f.readlines()
        assert len(lines) == 2, f"expected exactly 2 items to survive, found {len(lines)}"

        print("PASS: progress_log detects and reports a failed write(), and stops without corrupting the log")


if __name__ == "__main__":
    main()
```

```bash
$ python3 test_progress_log.py
PASS: progress_log detects and reports a failed write(), and stops without corrupting the log
```

Non servono framework di test complessi o fixture pesanti. Sono sufficienti `subprocess` e delle semplici istruzioni `assert` per avviare `strace` esattamente come abbiamo fatto da riga di comando, verificando i tre aspetti fondamentali che qualunque code reviewer esigerebbe: il processo deve terminare con un codice di errore, deve stampare una spiegazione chiara a terminale e deve lasciare il file di log in uno stato integro (contenente esattamente i primi 2 elementi validi, senza righe troncate o dati corrotti). Questo è il classico test dell'*unhappy path* che prima mancava del tutto, applicato a un codice che finora non aveva mai dovuto dimostrare la propria robustezza sul campo. Inserendo questo controllo nella pipeline di CI (prestando attenzione alle note sui container descritte più avanti), questo genere di regressioni verrà intercettato tempestivamente a ogni futura modifica di `progress_log.py`.

## 🤨 Perché non usare semplicemente un mock?

Si tratta di un'obiezione legittima. Si potrebbe usare semplicemente `unittest.mock.patch("builtins.open")` per sollevare manualmente un `OSError` e verificare che venga intercettato correttamente. Niente `strace`, niente `subprocess`, nessun problema con `ptrace` in ambiente CI. Sembra una via molto più semplice e lineare, e in effetti lo è.

Il punto è che in questo modo si sta testando uno scenario completamente diverso. Se usi un mock per simulare l'errore, ti stai limitando a verificare che il blocco `except OSError` intercetti l'eccezione che tu stesso hai sollevato artificialmente un istante prima. Questo test è corretto per costruzione, ma non garantisce affatto che il codice si comporti bene quando è la *vera* syscall `write()` a fallire a livello di sistema operativo. Un mock, infatti, non simula minimamente la complessità del reale stack di I/O.

Questa differenza non è teorica. Ci ha già fregati una volta in questo stesso post. Il buffer che silenziosamente ritenta la scrittura su `close()`, l'intero motivo per cui `progress_log` apre il file con `buffering=0`, si manifesta solo quando una `write()` vera fallisce per davvero, dentro il vero livello di buffering di Python. Se mocki `open()`, quel livello semplicemente non fa più parte del test. Il problema resta invisibile e il bug finisce comunque in produzione.

Il fault injection operato direttamente a livello di syscall non richiede alcuna modifica o predisposizione nel codice dell'applicazione. Non ci sono punti di ingresso da patchare o configurare, e funziona allo stesso modo sia che si stia testando un subprocess, una libreria esterna o un binario precompilato di cui non si possiedono i sorgenti. Se il mocking si rivela uno strumento formidabile per testare la logica di business pura, non è in grado di dirci nulla su come il nostro software interagisce con il kernel attraverso il confine delle syscall — ed è proprio questo confine il fulcro di tutta questa serie.

## ⚠️ Qualche importante avvertenza

Ecco due aspetti pratici a cui prestare molta attenzione (ed entrambi ci hanno fatto sbattere la testa in passato):

**Circoscrivi sempre il fault injection con precisione.** L'esecuzione senza un ambito (scope) definito di prima non è fallita nel punto esatto che volevamo testare: è fallita *in un punto reale del sistema*, solo che non era quello da noi scelto. Se lanci `--inject` contro un servizio di produzione o critico, un filtro non ben delimitato rischia di compromettere percorsi di esecuzione del codice che non avevi alcuna intenzione di toccare. Usa sempre l'opzione `-P` (o un filtro `-e trace=` molto restrittivo) prima di avviare questo strumento su contesti più complessi o delicati di un semplice binario di test.

**`strace` richiede `ptrace`**, una syscall che i container tendono a bloccare per motivi di sicurezza. `strace` deve essere eseguito con lo stesso UID del processo target o disporre della capability `CAP_SYS_PTRACE`. Inoltre, il profilo seccomp predefinito di Docker blocca `ptrace` a prescindere. Di conseguenza, per far funzionare tutto questo all'interno di un container standard (aspetto fondamentale se intendi integrare questi test in una pipeline di CI/CD), dovrai avviarlo usando l'opzione `--cap-add=SYS_PTRACE` oppure `--security-opt seccomp=unconfined`.

Affronteremo la questione dell'overhead più avanti nella serie, quando confronteremo questo approccio con seccomp ed eBPF.

## 🏁 Tirando le somme

In questo articolo abbiamo esplorato la reale natura di una syscall, compreso l'utilità di simularne il fallimento e implementato il nostro primo meccanismo di fault injection funzionante senza dover scrivere una sola riga di codice di test invasivo. Tutto il lavoro pesante è affidato a `strace`, mentre `progress_log.py` funge da bersaglio ideale. Abbiamo affrontato e risolto un'insidia comune legata al modo in cui viene conteggiata la "terza chiamata" e, anziché accontentarci del classico "funziona sulla mia macchina", abbiamo consolidato l'esperimento in un test automatizzato pronto per intercettare qualsiasi regressione futura. Dopotutto, il vero traguardo non era semplicemente osservare una chiamata `write()` che fallisce, ma dimostrare empiricamente che la nostra applicazione è in grado di gestire la situazione d'emergenza con eleganza.

Nel prossimo articolo abbandoneremo `strace` per scrivere il nostro personalissimo tool di iniezione basato su `ptrace`. Questo ci aprirà la strada a scenari di errore complessi che l'opzione `--inject` standard non è in grado di riprodurre, come ad esempio una chiamata `write()` che restituisce un successo parziale scrivendo solo una porzione del buffer. Per quell'esperimento selezioneremo il target ideale per metterne in luce i dettagli di funzionamento, senza vincolarci necessariamente all'applicazione usata oggi.

Il sorgente completo di questo capitolo è quello inserito sopra. `progress_log.py` e `test_progress_log.py`, senza modifiche, sono ciò che ha generato ogni singolo output di questo post.

## 📚 Crediti e approfondimenti

La [pagina man di `strace(1)`](https://man7.org/linux/man-pages/man1/strace.1.html) documenta per intero i flag `--inject`/`-e inject=`. Il [talk di Dmitry Levin al FOSDEM 2017](https://archive.fosdem.org/2017/schedule/event/failing_strace/attachments/slides/1630/export/events/attachments/failing_strace/slides/1630/strace_fosdem2017_ta_slides.pdf) sul fault injection di strace racconta lo stesso lavoro dal punto di vista del maintainer, insieme al [progetto GSoC del 2016](https://lists.strace.io/pipermail/strace-devel/2016-March/004649.html) che lo ha fatto partire. E se questo post ti ha incuriosito, i miei articoli precedenti coprono un terreno simile: [Expect the unexpected](https://ilmanzo.github.io/it/post/faulty_disk_simulation/) parla di guasti al disco simulati con device mapper, e [Fault Injection in Network Namespace and Veth Environments](https://ilmanzo.github.io/it/post/faulty_network_simulation/) fa lo stesso con `netem`.

Buon (fault) hacking!
