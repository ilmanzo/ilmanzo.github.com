---
layout: post
title: "Quanto codice stai testando? (2)"
description: "Misurare la copertura dei test sui binari"
categories: [programming, testing]
tags: [testing, tutorial, linux, coverage, e2e, qa, tracing, scripting]
series: ["How much code are you testing?"]
series_order: 2
author: Andrea Manzini
date: 2025-03-30
---

## ▶️ Introduzione

Nel [post precedente](https://ilmanzo.github.io/it/post/measuring-coverage-of-integration-tests/) abbiamo iniziato il nostro viaggio con uno scenario molto semplice, e abbiamo utilizzato una [comoda funzionalità](https://go.dev/blog/integration-test-coverage) del linguaggio di programmazione Go per misurare quale percentuale del programma target viene esercitata dal nostro test.

Questa volta sperimenterò una Proof of Concept su come ottenere una stima della metrica di copertura del codice di test per un normale programma binario, **senza alcuna ricompilazione.**

In questo esempio faremo finta che il nostro compito sia scrivere test di integrazione per il famoso programma `gzip`, e cercheremo di misurare i progressi che stiamo facendo riguardo alla *copertura* dei nostri test.

![coverage](/img/pexels-emhopper-1359036.jpg)
*Anche gli animali domestici hanno bisogno di copertura!* Crediti immagine: [Em Hopper](https://www.pexels.com/@emhopper/)

## 🧮 Come?

L'idea principale è:
- ottenere in qualche modo l'elenco *completo* delle funzioni presenti nel programma = N
- registrare, durante il test, quali di queste funzioni vengono eseguite = E

Il rapporto E/N fornisce un'approssimazione dell'efficacia del test, guidandoci verso le aree che necessitano di un'estensione della copertura.

Non vogliamo ricompilare `gzip` con la strumentazione di copertura, ma nella nostra distribuzione abbiamo le *informazioni di debug (debuginfo)* del programma. Di solito sono fornite in pacchetti separati e il repository non è abilitato di default, quindi prima di tutto abilitiamoli e installiamo i relativi pacchetti.
Su Tumbleweed:

```bash
$ sudo zypper modifyrepo -e repo-debug 
$ sudo zypper refresh
$ sudo zypper in gzip-debuginfo gzip-debugsource
```

## 👐 Funzioni fino in fondo

Possiamo usare il debugger `gdb` per avere un elenco di tutte le funzioni in un programma:

```bash
$ sudo zypper install gdb
$ gdb /usr/bin/gzip
For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from /usr/bin/gzip...
Reading symbols from /usr/lib/debug/usr/bin/gzip.debug...
(gdb) info functions
All defined functions:
File ../sysdeps/x86_64/start.S:
        void _start(void);

File ./lib/stat-time.h:
29:     int openat_safer(int, const char *, int, ...);
30:     int rpl_printf(const char *, ...);
116:    int unzip(int, int);
[... long output omitted ...]
```

Sembra promettente!

## ☝️ Scrivere il primo test

Come l'ultima volta, per semplicità useremo il framework `pytest`, ma [qualsiasi altro](https://open.qa/) andrebbe altrettanto bene. Per prima cosa, scriviamo uno *smoke test*:

```python
# test_gzip.py
import os,re
from subprocess import run

PROGRAM='/usr/bin/gzip'

# program should display help
def test_help(capfd):
    process=run([PROGRAM,'-h'])
    stdout, stderr = capfd.readouterr()     
    assert process.returncode == 0
    assert "Usage:" in stdout 
```

In questo test, avviamo un processo per eseguire semplicemente `gzip -h`, aspettandoci un output specifico.
eseguiamolo:

```bash
============================= test session starts ==============================
platform linux -- Python 3.13.2, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/binarycoverage
collected 1 item

test_gzip.py .                                                            [100%]

============================== 1 passed in 0.01s ===============================
```

## 👣 Tracciarlo

Ora possiamo tracciare quali funzioni sono state esercitate avvolgendo l'esecuzione del test con il potente strumento [`valgrind`](https://valgrind.org/):

```bash
$ sudo zypper install valgrind
$ valgrind --tool=callgrind --trace-children=yes pytest
```

l'esecuzione richiede un po' più di tempo e otteniamo alcuni nuovi file che contengono i dati di tracciamento:

```bash
$ ls -l callgrind.out.*
-rw-------. 1 andrea andrea 1944681 Mar 30 17:54 callgrind.out.2771
-rw-------. 1 andrea andrea   82977 Mar 30 17:54 callgrind.out.2816
```

Questi file di dati sono destinati a essere elaborati da [callgrind_annotate](https://valgrind.org/docs/manual/cl-manual.html#cl-manual.callgrind_annotate-options) che produrrà un report dettagliato con tutte le funzioni eseguite (comprese quelle in librerie come `glibc`).

```
$ callgrind_annotate callgrind.out.2816
--------------------------------------------------------------------------------
Profile data file 'callgrind.out.2816' (creator: callgrind-3.24.0)
--------------------------------------------------------------------------------
I1 cache:
D1 cache:
LL cache:
Timerange: Basic block 0 - 52685
Trigger: Program termination
Profiled target:  /usr/bin/gzip -h (PID 2816, part 1)
Events recorded:  Ir
Events shown:     Ir
Event sort order: Ir
Thresholds:       99
Include dirs:
User annotated:
Auto-annotation:  on

--------------------------------------------------------------------------------
Ir
--------------------------------------------------------------------------------
246,004 (100.0%)  PROGRAM TOTALS

--------------------------------------------------------------------------------
Ir               file:function
--------------------------------------------------------------------------------
41,382 (16.82%)  /usr/src/debug/glibc-2.41/elf/dl-lookup.c:do_lookup_x [/usr/lib64/ld-linux-x86-64.so.2]
40,596 (16.50%)  /usr/src/debug/glibc-2.41/elf/dl-reloc.c:_dl_relocate_object_no_relro [/usr/lib64/ld-linux-x86-64.so.2]
17,388 ( 7.07%)  /usr/src/debug/glibc-2.41/elf/dl-lookup.c:_dl_lookup_symbol_x [/usr/lib64/ld-linux-x86-64.so.2]
13,781 ( 5.60%)  /usr/src/debug/glibc-2.41/elf/dl-tunables.c:__GI___tunables_init [/usr/lib64/ld-linux-x86-64.so.2]
13,309 ( 5.41%)  /usr/src/debug/glibc-2.41/elf/../sysdeps/generic/dl-new-hash.h:_dl_lookup_symbol_x
11,941 ( 4.85%)  /usr/src/debug/glibc-2.41/string/../sysdeps/x86_64/multiarch/../multiarch/strcmp-sse2.S:strcmp [/usr/lib64/ld-linux-x86-64.so.2]
 9,951 ( 4.05%)  /usr/src/debug/glibc-2.41/elf/dl-lookup.c:check_match [/usr/lib64/ld-linux-x86-64.so.2]
 8,321 ( 3.38%)  /usr/src/debug/glibc-2.41/elf/do-rel.h:_dl_relocate_object_no_relro
 7,033 ( 2.86%)  /usr/src/debug/gzip-1.13/lib/vasnprintf.c:vasnprintf [/usr/bin/gzip]
 6,968 ( 2.83%)  /usr/src/debug/glibc-2.41/elf/../sysdeps/x86_64/dl-machine.h:_dl_relocate_object_no_relro
 5,935 ( 2.41%)  /usr/src/debug/glibc-2.41/elf/../sysdeps/x86/dl-cacheinfo.h:intel_check_word.constprop.0 [/usr/lib64/ld-linux-x86-64.so.2]
 4,811 ( 1.96%)  /usr/src/debug/glibc-2.41/elf/../bits/stdlib-bsearch.h:intel_check_word.constprop.0
 4,402 ( 1.79%)  /usr/src/debug/glibc-2.41/elf/dl-version.c:_dl_check_map_versions [/usr/lib64/ld-linux-x86-64.so.2]
 4,356 ( 1.77%)  /usr/src/debug/glibc-2.41/elf/dl-tunables.h:__GI___tunables_init
 4,348 ( 1.77%)  /usr/src/debug/gzip-1.13/lib/printf-parse.c:vasnprintf
 2,660 ( 1.08%)  /usr/src/debug/glibc-2.41/stdio-common/vfprintf-internal.c:__printf_buffer [/usr/lib64/libc.so.6]
 2,064 ( 0.84%)  /usr/src/debug/glibc-2.41/stdio-common/Xprintf_buffer_write.c:__printf_buffer_write [/usr/lib64/libc.so.6]
```

Sebbene sia un po' prolisso, contiene tutte le informazioni di cui abbiamo bisogno. Ha solo bisogno di una sistematina...

## 🤖 Automatizzarlo

Per renderci la vita più facile, conviene usare un po' di scripting di incollaggio (glue scripting) per automatizzare gli strumenti e analizzare i dati con del codice Python per ottenere le informazioni di cui abbiamo bisogno. Il progetto completo [è disponibile sul mio repository GitHub](https://github.com/ilmanzo/binarycoverage_callgrind), ma ecco un estratto dello script `coverage.sh` che esegue `pytest` e produce la misura di copertura:

```bash
#!/bin/bash
BINARY=gzip
TEMP_DIR=$(mktemp -d)
valgrind --tool=callgrind --trace-children=yes \
  --callgrind-out-file=$TEMP_DIR/callgrind.%p pytest 2> /dev/null
# dump all the functions in the binary
gdb -ex 'set pagination off' -ex 'info functions' -ex quit \
  $(which $BINARY) > $TEMP_DIR/all_funcs.gdb
python3 calc_coverage.py --binary $BINARY -d $TEMP_DIR
# Clean up: Remove the temporary directory and its contents
rm -rf "$TEMP_DIR"
```

```
> ./coverage.sh
============================= test session starts ==============================
platform linux -- Python 3.13.2, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/binarycoverage
collected 1 item

test_gzip.py .                                                           [100%]

============================== 1 passed in 0.54s ===============================
--- Binary coverage report ---
Functions coverage: 9/80 11.25%
```

Come previsto, il nostro "smoke" test su `gzip` esegue solo 9 funzioni su 80, con una bassa copertura dell'11%.

## 🏃‍➡️ Andiamo avanti

Ora possiamo migliorare i nostri test, guidati dalla metrica di copertura. Proviamo con l'opzione `gzip -V`?

```python
# program should display version information
def test_version(capfd):
    process=run([PROGRAM,'-V'])
    stdout, stderr = capfd.readouterr()
    assert process.returncode == 0
    assert "This is free software" in stdout 
    assert re.search(r"gzip \d.\d\d", stdout)
```

Un semplice test per assicurarsi che il programma restituisca una versione numerica.

```
$ ./coverage.sh
============================= test session starts ==============================
collected 2 items

test_gzip.py ..                                                          [100%]

============================== 2 passed in 1.17s ===============================
--- Binary coverage report ---
Functions coverage: 10/80 12.50%
```

Un po' meglio! Aggiungiamo un test negativo per sicurezza:

```python
# program should fail when given a non existing file
def test_compress_non_existent():
    process=run([PROGRAM,'foobar'])
    assert process.returncode==1
```

```
$ ./coverage.sh
============================= test session starts ==============================
collected 3 items

test_gzip.py ...                                                         [100%]

============================== 3 passed in 1.51s ===============================
--- Binary coverage report ---
Functions coverage: 19/80 23.75%
```

Siamo sulla buona strada. Abbiamo raddoppiato la copertura, e ancora non abbiamo compresso nulla...

## 🏋️ Facciamo del lavoro vero

È ora di scrivere un test per comprimere e decomprimere un file! Introduciamo anche una funzione di supporto (helper) nel test, poiché ne avremo bisogno più di una volta:

```python
SAMPLE_FILE='sample.txt'

# program should compress and de-compress a file
def test_compress_decompress(capfd):
    create_test_file(SAMPLE_FILE)
    with open(SAMPLE_FILE) as file:
        content=file.readlines()
    process=run([PROGRAM,SAMPLE_FILE])
    assert process.returncode == 0
    compressed_file=SAMPLE_FILE+".gz"
    # decompress and read back content
    process=run([PROGRAM,'-d',compressed_file])
    assert process.returncode == 0
    with open(SAMPLE_FILE) as file:
        assert(file.readlines()==content)
    os.remove(SAMPLE_FILE)

# helper function to create a dummy sample file
def create_test_file(file_name):
    sample_text = """This is a dummy sample text file.
    It contains some random lines of text.
    This is line 3 of the text file.
    Here is line 4, just for testing purposes.
    Feel free to modify or extend this text.
    """
    # Open the file in write mode ('w') and write the sample text to it
    with open(file_name, 'w') as file:
        file.write(sample_text)    
```

```
> ./coverage.sh
============================= test session starts ==============================
collected 4 items

test_gzip.py ....                                                        [100%]

============================== 4 passed in 2.30s ===============================
--- Binary coverage report ---
Functions coverage: 52/80 65.00%
```

Questo è un grande progresso! I nostri test stanno migliorando. Ne facciamo un altro? Passiamo al *lato oscuro* e diamogli un file danneggiato:

```python
# program should give error on a damaged compressed file
def test_decompress_error(capfd):
    wrong_file='dummy.txt'
    create_test_file(wrong_file)
    wrong_compressed=wrong_file+'.gz'
    process=run([PROGRAM,wrong_file])
    # now damage the compressed file by writing a random byte
    with open(wrong_compressed, "r+b") as file:
        file.seek(32)
        file.write(bytes(0xFF))
    # decompression should fail        
    process=run([PROGRAM,'-d',wrong_compressed])
    stdout, stderr = capfd.readouterr()
    assert process.returncode==1
    assert 'invalid compressed data' in stderr
    os.remove(wrong_file+'.gz')
```

```
$ ./coverage.sh
============================= test session starts ==============================
collected 5 items

test_gzip.py .....                                                       [100%]

============================== 5 passed in 3.02s ===============================
--- Binary coverage report ---
Functions coverage: 54/80 67.50%
```

Questo è un ottimo risultato! Vi vengono in mente aree di miglioramento?

## 💡 Ci sfugge qualcosa

Se usate l'opzione verbosa `-v`, lo script Python [`calc_coverage`](https://github.com/ilmanzo/binarycoverage_callgrind/blob/main/calc_coverage.py) mostrerà le funzioni che sono state testate e quelle che non lo sono state:

```
Executed functions: atdir_eq,atdir_set,bi_windup,build_tree,compress_block,ct_tally,discard_input_bytes,do_exit,fd_safer,file_read,fill_inbuf,fill_window,finish_out,finish_up_gzip,flush_block,flush_outbuf,flush_window,gen_codes,get_input_size_and_time,get_method,get_suffix,huft_build,huft_free,inflate_codes,inflate_dynamic,init_block,input_eof,last_component,license,longest_match,main,open_and_stat,open_safer,openat_safer,pqdownheap,progerror,read_buffer,remove_output_file,rpl_fclose,rpl_fflush,rpl_fprintf,rpl_printf,rpl_vfprintf,scan_tree,send_bits,send_tree,strlwr,treat_file,unzip,updcrc,vasnprintf,write_buf,xstrdup,zip

Missing functions : _start,abort_gzip_signal,copy,copy_block,direntry_cmp_name,display_ratio,do_list,fillbuf,fprint_off,gzip_error,inflate_fixed,make_table,mbszero,read_byte,read_error,read_pt_len,rpl_fcntl,rsync_roll,treat_stdin,try_help,unlzh,unlzw,unpack,write_error,xalloc_die,xpalloc
```

In questo modo, abbiamo anche alcuni *indizi* su quali funzionalità del programma non stiamo testando. In questo esempio, tra le altre cose possiamo citare la compatibilità con `rsync` e il supporto per i file `.Z`. Naturalmente, alcune (como le routine di gestione dei segnali) sono molto difficili da testare adeguatamente.

## 🧵 Considerazioni finali

È fondamentale ricordare che la percentuale di copertura ottenuta con questo metodo è un'approssimazione. `valgrind` traccia le chiamate alle funzioni, non le singole righe o i rami di esecuzione. Pertanto, una funzione potrebbe essere chiamata ma non completamente testata, portando a potenziali falsi positivi. Inoltre, le funzioni esercitate indirettamente da altre chiamate potrebbero non essere esplicitamente elencate, con conseguenti falsi negativi. Il sovraccarico di prestazioni introdotto da `valgrind` significa anche che questa tecnica è più adatta per analisi offline che per test in tempo reale.

D'altra parte, offre il vantaggio di essere semplice da implementare, non richiede grandi sforzi né configurazioni particolari e potete usarlo come indicatore per capire se i test di integrazione che state scrivendo stanno migliorando nel tempo o meno. Un altro buon utilizzo può essere quello di rilevare quando una nuova versione dei programmi introduce più funzionalità, poiché se la copertura diminuisce con l'aggiornamento, significa che non state testando le novità.

Grazie per avermi seguito fino alla fine di questo lungo post, sentitevi liberi di inviare commenti e feedback, happy hacking! :wave:
