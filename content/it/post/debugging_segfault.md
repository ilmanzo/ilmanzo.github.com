---
layout: post
title: "SEGFAULT: Debugging di un'applicazione che va in crash"
description: "Cos'è un core dump e come si usa per il debugging?"
categories: linux
tags: [linux, sysadmin, opensuse, programming, debugging]
author: Andrea Manzini
date: 2024-04-05
---

## 🙀 Qualcosa si rompe

Se usate Linux ed eseguite alcune applicazioni, potreste aver visto a volte un messaggio di errore simile a questo:

## `[1]    24975 segmentation fault (core dumped)`

cosa significa e come può essere utile? Scopriamolo insieme.

## 🧪 Preparazione del laboratorio

Per realizzare un caso di studio adeguato, abbiamo bisogno di un programma che vada in crash. Naturalmente al giorno d'oggi sono molto rari :grin: quindi ne creeremo uno noi stessi, mettendo in mostra le nostre peggiori abilità e pratiche di programmazione in C.

Attenzione: questo programma è scritto male appositamente per mostrare come funziona un segmentation fault, non è inteso per nessun altro scopo... Non fatelo in un contesto reale.
```c
// badprogram.c 
#include <stdio.h>
#include <string.h>

void makeitcrash() {
   char buffer[10000];
   memset(buffer, 0, sizeof(buffer));
   for(int i=1; i<100000; i*=2) buffer[i]='A'; // typo: a zero in excess
}

int main() {
   printf("Kaboom!");
   makeitcrash();
   return 0;
}
```

ora dobbiamo compilarlo, inserendo anche i simboli di debug nel binario, quindi useremo il flag `-g`:

```bash
$ gcc -g badprogram.c -o badprogram
./badprogram

[1]    7022 segmentation fault (core dumped)  ./badprogram
```

Ottimo, è fallito! Ma cosa è successo realmente? Come e dove ha "scaricato" (dumped) qualcosa? :shit:

## 🐕 Un po' di indagine

Ci sono [molte risorse là fuori](https://jvns.ca/blog/2018/04/28/debugging-a-segfault-on-linux/) che spiegano questa cosa meglio di me, ma per farla breve, quando un programma tenta di accedere a una regione di memoria non valida (in qualsiasi modo, ad esempio dereferenziando un puntatore `NULL`), il sistema operativo invia il *segnale 11 (SIGSEGV)* al processo. Il gestore dei segnali predefinito crea opzionalmente un file di "dump" che contiene la memoria del processo al momento dell'errore e lo termina con un messaggio improvviso.

Poiché possono occupare molto spazio, di solito i core dump sono compressi di default; possiamo verificare alcune informazioni sul core scaricato con l'utilità `coredumpctl`:

```bash
$ coredumpctl info badprogram

           PID: 4269 (badprogram)
           UID: 1000 (andrea)
           GID: 1000 (andrea)
        Signal: 11 (SEGV)
     Timestamp: Fri 2024-04-05 11:13:45 CEST (6s ago)
  Command Line: ./badprogram
    Executable: /home/andrea/projects/coredumper/badprogram
          Unit: user@1000.service
     User Unit: vte-spawn-68d635ed-58e5-4522-95ee-2deb64da991a.scope
         Slice: user-1000.slice
     Owner UID: 1000 (andrea)
       Boot ID: [blablabla]
    Machine ID: [blablabla]
      Hostname: localhost
       Storage: /var/lib/systemd/coredump/core.badprogram.1000.9d49cca5818645e4baacc1ddddd7a9e8.4269.1712308425000000.zst (present)
  Size on Disk: 25.3K
       Message: Process 4269 (badprogram) of user 1000 dumped core.
                
                Stack trace of thread 4269:
                #0  0x0000000000401152 n/a (/home/andrea/projects/prove/coredumper/badprogram + 0x1152)
                #1  0x0000000000401175 n/a (/home/andrea/projects/prove/coredumper/badprogram + 0x1175)
                #2  0x00007f112f02a1f0 __libc_start_call_main (libc.so.6 + 0x2a1f0)
                #3  0x00007f112f02a2b9 __libc_start_main@@GLIBC_2.34 (libc.so.6 + 0x2a2b9)
                #4  0x0000000000401075 n/a (/home/andrea/projects/prove/coredumper/badprogram + 0x1075)
                ELF object binary architecture: AMD x86-64

```

nota a margine: si può sempre ottenere un dump da un programma in esecuzione inviando un segnale `SIGABRT` al suo ID di processo, come:

`$ kill -ABRT $(pidof firefox-bin)`

## ⛏️ Più a fondo

Decomprimiamo quel file compresso in una posizione comoda ed esaminiamolo un po':

```bash
$ zstd --uncompress /var/lib/systemd/coredump/core.badprogram.1000.9d49cca5818645e4baacc1ddddd7a9e8.4269.1712308425000000.zst -o badprogram.core
/var/lib/systemd/coredump/core.badprogram.1000.9d49cca5818645e4baacc1ddddd7a9e8.4269.1712308425000000.zst: 475136 bytes 
$ ls -l
-rwxr-xr-x 1 andrea andrea  21152 apr  5 11:08 badprogram*
-rw-r--r-- 1 andrea andrea    240 apr  5 09:30 badprogram.c
-rw-r----- 1 andrea andrea 475136 apr  5 11:13 badprogram.core
```
Ora eseguiamo nuovamente il programma difettoso, ma questa volta con l'aiuto del Gnu Debugger e passando anche il file coredump:

```bash
$ gdb ./badprogram -c badprogram.core 

Program terminated with signal SIGSEGV, Segmentation fault.
#0  0x0000000000401188 in makeitcrash () at badprogram.c:7
7	   for(int i=1; i<100000; i*=2) buffer[i]='A';
(gdb) bt
#0  0x0000000000401188 in makeitcrash () at badprogram.c:7
#1  0x00000000004011bd in main () at badprogram.c:12
(gdb) print i
$1 = 32768
(gdb) 
$2 = 32768
(gdb) info locals
i = 32768
buffer = "\000AA\000A\000\000\000A\000\000\000\000\000\000\000A", '\000' <repeats 15 times>, "A", '\000' <repeats 31 times>, "A", '\000' <repeats 63 times>, "A", '\000' <repeats 127 times>...
```
grazie alle informazioni di debug incluse durante la compilazione, siamo in grado di vedere la sorgente del codice incriminato e il valore della variabile quando si è verificato il problema, offrendoci un punto di partenza per rimediare al nostro errore.

Quindi, alla fine, qual è la differenza tra avere un file coredump o meno? Perché non possiamo semplicemente ri-eseguire lo stesso programma e lasciarlo andare in crash sotto GDB?

`Il punto è avere tra le mani l'esatto snapshot della memoria del programma nel momento in cui è andato in crash.`

Forse non è fattibile eseguirlo ora, oppure non abbiamo lo stesso ambiente o non possiamo ricreare las stesse condizioni sul nostro PC. Ma grazie ai **core dump** siamo in grado di viaggiare nel tempo fino a quel passato. 

#### Consiglio extra: esegui gdb con l'opzione `-tui` o digita `tui enable` al prompt per ottenere una bella [interfaccia](https://dev.to/irby/making-gdb-easier-the-tui-interface-15l2) intuitiva :smile:

## 🚪 Considerazioni finali

Naturalmente non sarà sempre così facile, ma essere in grado di ispezionare la memoria di un processo di un programma terminato è uno strumento di debugging inestimabile. Un'osservazione importante è che spesso i pacchetti che installiamo non hanno informazioni di debug incluse, quindi dobbiamo installarle separatamente o compilare il codice sorgente da soli. Anche il kernel stesso può essere analizzato, utilizzando i [kernel crash core dump](https://www.suse.com/support/kb/doc/?id=000016171). Su Linux, persino gli errori e i crash sono belli e utili! 

Come approfondimento sul debugging con GDB, consiglio di leggere questo eccellente [post sul blog](https://www.brendangregg.com/blog/2016-08-09/gdb-example-ncurses.html) di Brendan Gregg.
