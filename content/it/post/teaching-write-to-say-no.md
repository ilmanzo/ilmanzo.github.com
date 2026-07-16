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

Ogni volta che il tuo programma legge un file, scrive su un socket o alloca memoria, a un certo punto deve chiedere al kernel di farlo per davvero. Quella richiesta è una **syscall**: il confine stretto e ben definito dove il codice userspace passa nel kernel. `write()`, `read()`, `open()`, `mmap()` non sono semplici funzioni di libreria, sono l'intero vocabolario che il tuo programma ha a disposizione per parlare con il mondo esterno. Tutto il resto, `fwrite`, il `file.write()` di Python, `std::fs::File`, è solo un involucro attorno a questa manciata di punti di ingresso del kernel.

Questo conta perché è anche l'*unico* posto dove "il mondo esterno è andato storto" può davvero raggiungere il tuo programma. Un disco pieno, una connessione di rete caduta, un limite di file descriptor raggiunto, non sono bug nel tuo codice. Sono fatti dell'ambiente, e il kernel te li comunica in un solo modo: una syscall che ritorna un errore. Non ti sta mentendo. Sta semplicemente dicendo, onestamente, "no, questo adesso non lo posso fare." Se il tuo codice quel "no" lo *ascolti* davvero è tutta un'altra storia.

## 💥 Perché rompere le cose apposta?

Ecco la scomoda verità: il codice di gestione degli errori è, quasi sempre, il codice meno testato di tutta la codebase. Puoi scrivere un `except OSError` perfettamente ragionevole intorno a una `write()`, ma se il disco non si riempie mai davvero durante i test, quel ramo non viene mai eseguito. Finisce in produzione non testato, e la prima volta che *viene* eseguito è davanti a un utente vero, con dati veri in gioco.

I fallimenti reali come "disco pieno" o "connessione interrotta" sono rari e scomodi da riprodurre a comando. **Il fault injection li rende economici e ripetibili.** Invece di sperare che il tuo codice di gestione degli errori funzioni, forzi tu stesso il fallimento, quando vuoi tu, e guardi cosa succede davvero.

Esiste un modo nativo del kernel per farlo, `/sys/kernel/debug/fail_function`, ma richiede un kernel compilato con il supporto al fault injection di debug, che non tutti hanno. Buona notizia: per il confine delle syscall in particolare, c'è uno strumento con una barriera d'ingresso molto più bassa, già presente sul tuo sistema.

## 🧪 Ecco progress_log

Ogni tecnica di fault injection di questa serie ha il suo piccolo target costruito su misura, niente framework, niente codebase condivisa da studiare prima. Per strace vogliamo qualcosa di semplice il più possibile.

Ecco `progress_log`. Elabora un batch di "elementi", scrivendo una riga per ogni elemento in un file di log man mano che procede, il classico log di checkpoint di cui ogni job batch ha bisogno, così se muore a metà strada sai esattamente dove.

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

Quella docstring segnala qualcosa su cui vale la pena fermarsi, anche in un post che vuole restare semplice. Un normale `open(path, "w")` bufferizza quello che scrivi, e quando una scrittura bufferizzata fallisce, Python non butta necessariamente via i byte falliti. Una `close()` successiva può riuscire a scaricarli comunque, *dopo* che il tuo codice ha già detto all'utente che la scrittura era fallita. `buffering=0` evita tutto questo alla radice: quello che scrivi diventa subito una syscall, senza retry nascosti. È una trappola reale da conoscere anche fuori dal fault injection, capita solo che *dentro* conti molto di più.

Questo blocco `except OSError` è il nostro codice di gestione errori, il tipo che normalmente non viene mai eseguito. Facciamolo eseguire. Nessun passaggio di build richiesto:

```bash
$ chmod +x progress_log.py
$ ./progress_log.py 3 progress.log
processed item 1
processed item 2
processed item 3
done: processed 3 items
```

Tracciarlo mostra esattamente quello che ci aspettiamo: una `write()` sul file di log (fd 3), poi una `write()` su stdout (fd 1) per il messaggio di avanzamento, alternate.

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

Un attimo, è fallito l'**elemento 2**, non il 3. Abbiamo sbagliato a contare? Il log di strace dice di no:

```bash
$ cat naive.strace.log
write(3, "processed item 1\n", 17)      = 17
write(1, "processed item 1\n", 17)      = 17
write(3, "processed item 2\n", 17)      = -1 ENOSPC (No space left on device) (INJECTED)
write(2, "stopped at item 2: [Errno 28] No"..., 54) = 54
+++ exited with 1 +++
```

Eccolo. `when=3` conta la **terza syscall `write()` che il processo fa, punto**, e anche il nostro messaggio di avanzamento su stdout (`processed item 1`, fd 1) è una `write()`. Al kernel non importa e non sa che intendevamo rompere solo il file di log, `-e inject=write:...` fa match sul nome della syscall attraverso ogni file descriptor. È esattamente il tipo di assunzione che frega chiunque la prima volta che prova il fault injection: il fallimento che ottieni è reale, semplicemente non è dove pensavi che sarebbe atterrato.

## 🎯 Delimitare il raggio d'azione con `-P`

strace può restringere il tracciamento, e come effetto collaterale anche il contatore dell'injection, alle syscall che toccano un percorso specifico, tramite `-P`. Su strace 7.1, un percorso **relativo** non fa match con nulla, silenziosamente. Nessuna write viene tracciata, nessuna viene iniettata, e il programma arriva in fondo indisturbato, anche quando la directory corrente è esattamente quella dove si trova il file.

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

Adesso solo le `write()` sul descrittore del file di log vengono tracciate *e* contate, quindi `when=3` finalmente significa quello che volevamo:

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

Gli elementi 1 e 2 sono al sicuro su disco, l'elemento 3 è stato rifiutato esattamente come lo rifiuterebbe un disco davvero pieno, e il nostro `except OSError` lo ha catturato in modo pulito. Nessun traceback, nessun file corrotto in silenzio, solo il messaggio di errore che abbiamo scritto apposta per questa situazione. Quel ramo di gestione errori è appena entrato in azione per la prima volta.

## 🧫 Da guardare a verificare

Guardare l'output del terminale va bene per un post, è inutile per una test suite. L'obiettivo vero non è mai stato "guardare il fallimento succedere," è "verificare che la gestione degli errori faccia la cosa giusta." Trasformiamo quindi la demo manuale in qualcosa che può far fallire una build:

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

Nessun framework di test, nessuna fixture. `subprocess` e `assert` bastano per lanciare `strace` esattamente come abbiamo fatto a mano, e verificare tre cose che qualsiasi revisore chiederebbe: è uscito con codice diverso da zero, ha detto perché, e ha lasciato il file in uno stato coerente (2 elementi buoni, non 3, non spazzatura). Questo è il test dell'unhappy path che prima di oggi non esisteva, eseguito su codice che prima di oggi non aveva mai dovuto dimostrare di funzionare. Mettilo in CI (attenzione alla nota sui container e `ptrace` più sotto) e questo tipo di regressione resta beccato per sempre, a ogni futura modifica di `progress_log.py`.

## 🤨 Perché non usare semplicemente un mock?

Obiezione legittima. Potresti tirare fuori `unittest.mock.patch("builtins.open")`, sollevare tu stesso un `OSError`, e verificare che venga catturato. Niente `strace`, niente `subprocess`, nessun bisogno di `ptrace` in CI. Sembra più semplice, e onestamente lo è.

Sta anche testando tutta un'altra cosa. Se mocki il fallimento, in realtà stai solo verificando che il tuo `except OSError` catturi un `OSError`, quello stesso che gli hai appena passato tu un attimo prima. È vero per costruzione, e non dice nulla su cosa succede quando la *vera* syscall `write()` fallisce davvero, perché un mock non si avvicina mai nemmeno un po' al vero stack di IO.

Questa differenza non è teorica. Ci ha già fregati una volta in questo stesso post. Il buffer che silenziosamente ritenta la scrittura su `close()`, l'intero motivo per cui `progress_log` apre il file con `buffering=0`, si manifesta solo quando una `write()` vera fallisce per davvero, dentro il vero livello di buffering di Python. Se mocki `open()`, quel livello semplicemente non fa più parte del test. Il problema resta invisibile e il bug finisce comunque in produzione.

L'injection a livello di syscall non chiede nulla al tuo codice. Non c'è nessun punto da predisporre per il patch, e funziona esattamente allo stesso modo che tu stia colpendo un subprocess, una libreria di terze parti, o un binario di cui non hai nemmeno il sorgente. Il mocking è ottimo per la logica pura. Semplicemente non può dirti granché su come si comporta il tuo codice al vero confine attraverso cui il kernel ti parla, ed è esattamente quel confine il tema di tutta questa serie.

## ⚠️ Una parola di cautela

Due cose concrete a cui stare attenti, entrambe capitate proprio a noi.

Delimita l'injection con intenzione. Il run senza scope di prima non è fallito dove volevamo, è fallito *da qualche parte di reale*, semplicemente non dove avevamo scelto. Lancia `--inject` contro un servizio che conta davvero e un filtro non delimitato può abbattere un percorso di codice che non intendevi toccare affatto. Punta sempre su `-P` (o un `-e trace=` più stretto) prima di puntare questo strumento su qualcosa di più serio di un binario di prova usa e getta.

E `strace` ha bisogno di `ptrace`, che i container adorano bloccare. Deve girare come lo stesso utente del target, o avere `CAP_SYS_PTRACE`, e il profilo seccomp di default di Docker nega `ptrace` a prescindere. Ti servirà `--cap-add=SYS_PTRACE` oppure `--security-opt seccomp=unconfined` per far girare tutto questo dentro un container di default, cosa che conta parecchio se speravi di infilarlo dritto in CI.

Affronteremo la questione dell'overhead più avanti nella serie, quando confronteremo questo approccio con seccomp ed eBPF.

## 🏁 Tirando le somme

Abbiamo visto cos'è davvero una syscall, perché vale la pena farle fallire apposta, e ottenuto il nostro primo fault injection funzionante senza scrivere una riga di codice di injection nostro. strace fa il lavoro, `progress_log.py` è solo qualcosa su cui puntarlo. Ci siamo scontrati con un vero gotcha su cosa conta davvero "la terza chiamata," per due volte, e invece di fermarci a "beh, ha funzionato quando l'ho lanciato io," abbiamo trasformato tutto in un'asserzione capace di beccare una regressione da sola. Era questo l'obiettivo vero fin dall'inizio: non guardare `write()` fallire, ma dimostrare che il nostro codice sa gestirlo quando succede.

Nella prossima puntata usciamo da `strace` e costruiamo un nostro strumento basato su `ptrace`, che apre le porte a fallimenti che `--inject` non può fare, come una `write()` che "riesce" ma scrive solo una parte del buffer. Quel capitolo sceglierà qualsiasi target metta meglio in mostra quel meccanismo, senza dare per scontato che sia lo stesso programma di oggi.

Il sorgente completo di questo capitolo è quello inserito sopra. `progress_log.py` e `test_progress_log.py`, senza modifiche, sono ciò che ha generato ogni singolo output di questo post.

## 📚 Crediti e approfondimenti

La [pagina man di `strace(1)`](https://man7.org/linux/man-pages/man1/strace.1.html) documenta per intero i flag `--inject`/`-e inject=`. Il [talk di Dmitry Levin al FOSDEM 2017](https://archive.fosdem.org/2017/schedule/event/failing_strace/attachments/slides/1630/export/events/attachments/failing_strace/slides/1630/strace_fosdem2017_ta_slides.pdf) sul fault injection di strace racconta lo stesso lavoro dal punto di vista del maintainer, insieme al [progetto GSoC del 2016](https://lists.strace.io/pipermail/strace-devel/2016-March/004649.html) che lo ha fatto partire. E se questo post ti ha incuriosito, i miei articoli precedenti coprono un terreno simile: [Expect the unexpected](https://ilmanzo.github.io/it/post/faulty_disk_simulation/) parla di guasti al disco simulati con device mapper, e [Fault Injection in Network Namespace and Veth Environments](https://ilmanzo.github.io/it/post/faulty_network_simulation/) fa lo stesso con `netem`.

Buon (fault) hacking!
