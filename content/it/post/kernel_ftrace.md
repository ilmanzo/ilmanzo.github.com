---
layout: post
description: "Panoramica della funzionalità di tracciamento del kernel Linux"
title: "Il ftrace del kernel Linux"
categories: linux
tags: [tutorial, linux, kernel, tracing, syscall, sysadmin, debug]
author: Andrea Manzini
date: 2024-10-01
---

## 👣 Introduzione

Gli strumenti di tracciamento sono piuttosto popolari nell'ecosistema Unix/Linux; ad esempio, nello userspace abbiamo [ltrace](https://man7.org/linux/man-pages/man1/ltrace.1.html) per tracciare le chiamate di libreria dei programmi e [strace](https://en.wikipedia.org/wiki/Strace) per andare più a fondo e ispezionare l'uso delle syscall. 

Una delle molte caratteristiche che il kernel Linux offre dal 2008 (poi evolutasi nel tempo) è [ftrace](https://www.kernel.org/doc/html/latest/trace/ftrace.html), che permette diversi tipi di tracciamento a runtime. Sebbene non sia flessibile come la tecnologia [eBPF](https://ebpf.io/), può rivelarsi utile in alcune occasioni e non richiede un vero e proprio linguaggio di programmazione.

![traces](/img/pexels-karolina-grabowska-6633887.jpg)
[Foto di Karolina Kaboompics](https://www.pexels.com/photo/close-up-of-sidewalk-covered-in-snow-6633887/)

## 🐤 I concetti base

Prima di tutto, assicuriamoci che il vostro kernel sia compilato con l'opzione CONFIG_FTRACE e che il virtual filesystem di tracciamento sia montato:

```bash
# mount | grep tracefs
tracefs on /sys/kernel/tracing type tracefs (rw,nosuid,nodev,noexec,relatime)
```

così da poter ispezionare la sua comoda interfaccia a livello utente.

```bash
# cd /sys/kernel/tracing
# cat current_tracer 
nop
# cat README
tracing mini-HOWTO:

# echo 0 > tracing_on : quick way to disable tracing
# echo 1 > tracing_on : quick way to re-enable tracing

 Important files:
  trace                 - The static contents of the buffer
                          To clear the buffer write into this file: echo > trace
  trace_pipe            - A consuming read to see the contents of the buffer
  current_tracer        - function and latency tracers
  available_tracers     - list of configured tracers for current_tracer
  error_log     - error log for failed commands (that support it)
  buffer_size_kb        - view and modify size of per cpu buffer
  buffer_total_size_kb  - view total size of all cpu buffers
```

Ci sono un sacco di cose qui; abbiamo persino un fantastico *README* con un po' di documentazione, ma procediamo un passo alla volta.
Il file (virtuale) `current_tracer` contiene `nop`, il che significa che nessun tracciatore è abilitato. Dobbiamo modificarlo per poter tracciare qualcosa, e abbiamo una lunga lista di scelte:

## 🤔 Cosa posso fare?

```bash
# cat /sys/kernel/tracing/available_tracers 
timerlat osnoise blk function_graph wakeup_dl wakeup_rt wakeup function nop
```

- tracciatori di funzioni: `function`, `function_graph`
- tracciatori di latenza: `wakeup_dl`, `wakeup_rt`, `irqsoff`, `wakeup`, `timerlat` 
- tracciatori di I/O: `blk`
- IRQ/NMI: `osnoise`, `hwlat` 

Per abilitare un tracciatore, dobbiamo solo scrivere il suo nome in current_tracer:

```bash
# echo function > current_tracer
```

A questo punto è possibile attivare il tracciamento con `echo 1 > tracing_on` e iniziare a leggere dal file virtuale `trace` (che contiene il contenuto del trace buffer) o da `trace_pipe` (che trasmette i dati di tracciamento in streaming mentre li leggiamo).

## 🔧 Uno strumento migliore

Se interagire direttamente con il filesystem può risultare un po' scomodo, esiste un pratico strumento a riga di comando creato da [Steven Rostedt](https://github.com/rostedt) chiamato `trace-cmd`:

```bash
$ sudo zypper in trace-cmd
Loading repository data...
Reading installed packages...
Resolving package dependencies...

The following 3 NEW packages are going to be installed:
  libtraceevent1 libtracefs1 trace-cmd

3 new packages to install.
```

Vediamo alcuni esempi di utilizzo:

```bash
# trace-cmd start -p function
```

avvia il tracciamento con il tracciatore `function` (mostra le chiamate di funzione); una volta avviato, potete visualizzare i dati con 

```bash
# trace-cmd show
```

```
# tracer: function
#
# entries-in-buffer/entries-written: 51265/8953395   #P:1
#
#                                _-----=> irqs-off/BH-disabled
#                               / _----=> need-resched
#                              | / _---=> hardirq/softirq
#                              || / _--=> preempt-depth
#                              ||| / _-=> migrate-disable
#                              |||| /     delay
#           TASK-PID     CPU#  |||||  TIMESTAMP  FUNCTION
#              | |         |   |||||     |         |
    sshd-session-3242    [000] d..3.  5838.785487: finish_task_switch.isra.0 <-__schedule
    sshd-session-3242    [000] d..3.  5838.785488: _raw_spin_unlock <-finish_task_switch.isra.0
    sshd-session-3242    [000] ...1.  5838.785489: __fdget <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785490: sock_poll <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785490: tcp_poll <-sock_poll
    sshd-session-3242    [000] ...1.  5838.785491: tcp_stream_memory_free <-tcp_poll
    sshd-session-3242    [000] ...1.  5838.785492: __fdget <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785492: sock_poll <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785493: tcp_poll <-sock_poll
    sshd-session-3242    [000] ...1.  5838.785493: tcp_stream_memory_free <-tcp_poll
    sshd-session-3242    [000] ...1.  5838.785494: __fdget <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785495: tty_poll <-do_sys_poll
    sshd-session-3242    [000] ...1.  5838.785495: tty_ldisc_ref_wait <-tty_poll
    sshd-session-3242    [000] ...1.  5838.785496: ldsem_down_read <-tty_ldisc_ref_wait
    sshd-session-3242    [000] ...1.  5838.785496: __cond_resched <-ldsem_down_read
    sshd-session-3242    [000] ...1.  5838.785497: n_tty_poll <-tty_poll
    sshd-session-3242    [000] ...1.  5838.785500: tty_buffer_flush_work <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785500: flush_work <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785501: __cond_resched <-flush_work
    sshd-session-3242    [000] ...1.  5838.785501: __flush_work <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785502: __rcu_read_lock <-__flush_work
    sshd-session-3242    [000] ...1.  5838.785502: _raw_spin_lock_irq <-__flush_work
    sshd-session-3242    [000] d..2.  5838.785505: _raw_spin_unlock_irq <-__flush_work
    sshd-session-3242    [000] ...1.  5838.785506: __rcu_read_unlock <-__flush_work
    sshd-session-3242    [000] ...1.  5838.785506: tty_hung_up_p <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785507: mutex_is_locked <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785507: tty_chars_in_buffer <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785508: tty_write_room <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785508: pty_write_room <-n_tty_poll
    sshd-session-3242    [000] ...1.  5838.785509: tty_buffer_space_avail <-n_tty_poll
```

E per fermarlo usare `# trace-cmd stop`; potete anche svuotare il buffer con `# trace-cmd clear -a` o eseguire entrambe le operazioni con un semplice `# trace-cmd reset`.

Un esempio con un tracciatore diverso:

```bash
# trace-cmd start -p function_graph --max-graph-depth 5
```

Avvia il tracciamento di tutte le funzioni chiamate (fino a 5 livelli di profondità). Attenzione: può produrre un'enorme quantità di dati:

```bash
# trace-cmd show
```

```
# tracer: function_graph
#
# CPU  DURATION                  FUNCTION CALLS
# |     |   |                     |   |   |   |

 ------------------------------------------
 0)  sshd-se-3242  =>  kworker-3680 
 ------------------------------------------

 0)               |        finish_task_switch.isra.0() {
 0)   0.621 us    |          _raw_spin_unlock();
 0)   1.884 us    |        }
 0) ! 200.114 us  |      } /* __cond_resched */
 0)   0.601 us    |      mutex_unlock();
 0) ! 225.651 us  |    } /* flush_to_ldisc */
 0)   0.591 us    |    __cond_resched();
 0)   0.592 us    |    _raw_spin_lock_irq();
 0)   0.630 us    |    pwq_dec_nr_in_flight();
 0) ! 233.837 us  |  } /* process_one_work */
 0)               |  process_one_work() {
 0)   0.591 us    |    kick_pool();
 0)   0.591 us    |    set_work_pool_and_clear_pending();
 0)   0.591 us    |    _raw_spin_unlock_irq();
 0)               |    wq_barrier_func() {
 0)               |      complete() {
 0)   0.601 us    |        _raw_spin_lock_irqsave();
 0)               |        try_to_wake_up() {
 0)   0.591 us    |          _raw_spin_lock_irqsave();
 0)   0.611 us    |          ttwu_queue_wakelist();
 0)   0.861 us    |          raw_spin_rq_lock_nested();
 0)   0.711 us    |          update_rq_clock();
 0)   6.762 us    |          ttwu_do_activate();
 0)   0.591 us    |          _raw_spin_unlock();
 0)   0.611 us    |          _raw_spin_unlock_irqrestore();
 0) + 15.138 us   |        }
 0)   0.611 us    |        _raw_spin_unlock_irqrestore();
 0) + 18.515 us   |      }
 0) + 19.627 us   |    }
 0)   0.601 us    |    __cond_resched();
 0)   0.601 us    |    _raw_spin_lock_irq();
 0)   0.601 us    |    pwq_dec_nr_in_flight();
 0) + 27.621 us   |  }
 0)   0.622 us    |  worker_enter_idle();
 0)   0.592 us    |  _raw_spin_unlock_irq();
 0)               |  schedule() {
 0)               |    wq_worker_sleeping() {
 0)   0.611 us    |      kthread_data();
 0)   1.763 us    |    }
 0)   0.621 us    |    rcu_note_context_switch();
 0)               |    raw_spin_rq_lock_nested() {
 0)   0.590 us    |      _raw_spin_lock();
 0)   1.694 us    |    }
 0)   0.712 us    |    update_rq_clock();
 0)               |    dequeue_task() {
```

Mostrerà una visualizzazione ordinata delle chiamate di funzione nidificate che avvengono nel kernel, con i tempi in microsecondi a fianco.

## 📼 Registrazione e filtraggio 

Questo strumento può funzionare anche "registrando" in un file di dati tutti i punti di traccia raccolti, dopodiché possiamo usare la stessa utilità o [altre](https://kernelshark.org/) per ispezionare i dati.
Questo è particolarmente utile per eventi rari o se avete bisogno di fare il debug di problemi specifici che sembrano verificarsi in modo casuale.

```bash
# trace-cmd record
```

avvierà il tracciamento scrivendo i dati in un file (chiamato di default `trace.dat`). Dopo aver arrestato la traccia, potrete visualizzare i dati con

```bash
# trace-cmd report
```

Un filtro sull'evento `irq_handler` e sulla funzione `do_IRQ` mostrerà quanto tempo richiede l'IRQ nel kernel:

```bash
# trace-cmd record -p function_graph -l do_IRQ -e irq_handler_entry sleep 10
# trace-cmd report | grep irq_handler_entry -A 2


           sleep-4253  [000]  7340.590340: irq_handler_entry:    irq=27 name=virtio2-input.0
           sleep-4253  [000]  7340.590340: funcgraph_entry:        4.438 us   |          vring_interrupt();
           sleep-4253  [000]  7340.590345: funcgraph_exit:         6.201 us   |        }
--
           sleep-4253  [000]  7340.590767: irq_handler_entry:    irq=28 name=virtio2-output.0
           sleep-4253  [000]  7340.590769: funcgraph_exit:         3.136 us   |          }
           sleep-4253  [000]  7340.590769: funcgraph_entry:        0.270 us   |          _raw_spin_unlock();
--
          <idle>-0     [000]  7340.610004: irq_handler_entry:    irq=27 name=virtio2-input.0
          <idle>-0     [000]  7340.610011: funcgraph_exit:         8.436 us   |          }
          <idle>-0     [000]  7340.610011: funcgraph_entry:        1.031 us   |          add_interrupt_randomness();
--
    sshd-session-3242  [000]  7340.610566: irq_handler_entry:    irq=28 name=virtio2-output.0
    sshd-session-3242  [000]  7340.610571: funcgraph_exit:         8.456 us   |          }
    sshd-session-3242  [000]  7340.610572: funcgraph_entry:      + 11.051 us  |          irq_exit_rcu();
```

Per visualizzare tutte le operazioni di allocazione di memoria (del kernel) inferiori a 512 byte, possiamo filtrare sull'evento `kmalloc` e su un campo specifico:

```bash
# trace-cmd record -e kmem:kmalloc -f 'bytes_req < 512'

    sshd-session-3242  [000]  8115.304880: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d300 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.325365: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.344938: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.364728: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.385613: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.405250: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
    sshd-session-3242  [000]  8115.426718: kmalloc:              call_site=virtqueue_add_split+0xa9 ptr=0xffff95c7d458d1c0 bytes_req=32 bytes_alloc=32 gfp_flags=0x820 node=-1 accounted=false
```

Per ottenere tutte le funzioni/eventi/tracciatori disponibili e così via, potete usare le opzioni di `list`.

```bash
# trace-cmd list -h

trace-cmd version 3.2.0 (3.2.0)

usage:
 trace-cmd list [-e [regex]][-t][-o][-f [regex]]
          -e list available events
            -F show event format
            --full show the print fmt with -F
            -R show event triggers
            -l show event filters
          -t list available tracers
          -o list available options
          -f [regex] list available functions to filter on
          -P list loaded plugin files (by path)
          -O list plugin options
          -B list defined buffer instances
          -C list the defined clocks (and active one)
          -c list the supported trace file compression algorithms
```

## 🎩 Alcuni trucchi e suggerimenti

Invece di analizzare l'intero sistema, potreste voler tracciare le attività del kernel relative solo a uno specifico processo (PID), utilizzando l'opzione `-P`:

```bash
# trace-cmd record -p function -P 174
```

Su sistemi con pochissimo spazio su disco (come le schede embedded), non è facile memorizzare file di traccia di grandi dimensioni per analizzarli in seguito. `trace-cmd` può inviare la traccia in remoto su una rete. Basta avviarlo sull'host con l'opzione *listen port*:

```bash
# trace-cmd listen -p 12345 -D 
```

e poi sul dispositivo potete "salvare" eventi e dati sul peer remoto: 

```bash
# trace-cmd record -N mypc.local.net:12345 [tracing options]
``` 

Un trucco per gli sviluppatori di moduli: tracciate solo uno specifico modulo del kernel cercando funzioni che terminano con `]` (output parziale):

```bash
# lsmod | grep thinkpad
thinkpad_acpi         196608  0
platform_profile       12288  1 thinkpad_acpi
sparse_keymap          12288  1 thinkpad_acpi
rfkill                 40960  9 bluetooth,thinkpad_acpi,cfg80211
snd                   159744  57 snd_ctl_led,snd_hda_codec_generic,snd_seq,snd_seq_device,snd_hda_codec_hdmi,snd_hwdep,snd_hda_intel,snd_usb_audio,snd_usbmidi_lib,snd_hda_codec,snd_hda_codec_realtek,snd_sof,snd_timer,snd_compress,thinkpad_acpi,snd_soc_core,snd_ump,snd_pcm,snd_rawmidi
video                  81920  2 thinkpad_acpi,amdgpu
battery                28672  1 thinkpad_acpi

# trace-cmd list -f  | grep 'thinkpad_acpi]$ | grep bluetooh'
bluetooth_attr_is_visible [thinkpad_acpi]
bluetooth_set_status [thinkpad_acpi]
bluetooth_get_status [thinkpad_acpi]
bluetooth_exit [thinkpad_acpi]
bluetooth_shutdown [thinkpad_acpi]
bluetooth_enable_store [thinkpad_acpi]
bluetooth_enable_show [thinkpad_acpi]
bluetooth_write [thinkpad_acpi]
bluetooth_read [thinkpad_acpi]
```

e vedere quali utili funzioni possiamo mettere sotto traccia, o verificare come si comporta il nostro modulo appena sviluppato.

## 🏄‍♂️ Conclusione e riferimenti:

Se vi occupate di sviluppo del kernel o siete semplicemente curiosi di sapere come funzionano i meccanismi interni di Linux, potete fare affidamento su questa utile funzionalità per ottenere interessanti approfondimenti sul vostro sistema. 
Lascio qui alcuni altri siti web e post di blog che parlano di ftrace:
- [la documentazione ufficiale del Kernel](https://www.kernel.org/doc/html/latest/trace/ftrace.html)
- Un ottimo [Blog Post](https://sergioprado.blog/tracing-the-linux-kernel-with-ftrace/) di Sergio Prado 
- Due post su opensource.com di Gaurav Kamathe: [1](https://opensource.com/article/21/7/linux-kernel-ftrace) e [2](https://opensource.com/article/21/7/linux-kernel-trace-cmd)
- Un (vecchio ma prezioso) [articolo LWN](https://lwn.net/Articles/410200/)

Se la cosa vi interessa quanto a me, non esitate a lasciarmi commenti o feedback e sarò felice di fare un approfondimento 😉

Grazie per la lettura e Happy hacking!
