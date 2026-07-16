---
layout: post
title: "Aspettati l'inaspettato"
description: "Come migliorare il proprio software simulando un block device difettoso"
categories: linux
tags: [linux, sysadmin, programming, testing, device, storage]
author: Andrea Manzini
date: 2023-11-19
---

## *\"Sembri un disco rotto\"* 

È un modo di dire comune quando qualcuno ripete continuamente gli stessi concetti. Ma a volte anche un disco rotto (o danneggiato) può rivelarsi utile.

ATTENZIONE: Nessun filesystem o dispositivo è stato danneggiato durante la realizzazione di questo esperimento 😉

![broken-record](/img/pexels-mick-haupt-7663550.jpg)
Crediti immagine: [Mick Haupt](https://www.pexels.com/@mickhaupt/)


In questo articolo vorrei esplorare i potenti strumenti di cui disponiamo in Linux per simulare la gestione di dischi danneggiati, ovvero unità che segnalano errori in modo più o meno casuale.
Perché è importante? Perché simulando errori che prima o poi si verificheranno anche nel mondo reale, siamo in grado di creare software più robusto, capace di resistere a eventuali problemi dell'infrastruttura.

## Configurazione

Per evitare problemi nel nostro sistema di sviluppo e per rendere il processo il più portabile possibile, iniziamo creando un disco fittizio da 1 GB basato su un [loop device](https://en.wikipedia.org/wiki/Loop_device).

```bash
# dd if=/dev/zero of=/myfakedisk.bin bs=1M count=1024
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 0.446898 s, 2.4 GB/s

# losetup /dev/loop0 /myfakedisk.bin
```

Ora possiamo usare the loop device proprio come qualsiasi altro block device: possiamo creare un filesystem e montarlo

```bash
# mkfs.ext4 /dev/loop0
mke2fs 1.46.4 (18-Aug-2021)
Discarding device blocks: done                            
Creating filesystem with 262144 4k blocks and 65536 inodes
Filesystem UUID: bcba505c-54fa-49e5-852c-b5ea3faa53d0
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

# mkdir /mnt/good && mount /dev/loop0 /mnt/good && echo "test" > /mnt/good/test.txt && umount /mnt/good
```

il nostro \"disco virtuale\" funzionante è pronto; ora possiamo crearne uno difettoso utilizzando le funzionalità del [device mapper](https://docs.kernel.org/admin-guide/device-mapper/index.html) di Linux.

## Cos'è il device mapper?

![map](/img/pexels-monstera-production-7412095.jpg)
Crediti immagine: [Monstera Production](https://www.pexels.com/@gabby-k/)

Il Device Mapper di Linux è un framework a livello di kernel che consente la creazione di block device virtuali mappando dispositivi di storage fisici o volumi logici a questi dispositivi virtuali. Opera all'interno del kernel Linux, fornendo uno strato per creare, gestire e manipolare dispositivi di storage attraverso varie tecniche di mappatura come mirroring, striping, crittografia e snapshot. Questo framework consente l'implementazione di funzionalità di storage avanzate come la gestione dei volumi, il RAID e il thin provisioning, offrendo maggiore flessibilità, scalabilità e affidabilità nella gestione delle risorse di storage all'interno del sistema operativo Linux.

In pratica, creeremo una \"mappa\" tra il nostro dispositivo funzionante e uno \"nuovo\", con questo schema approssimativo:

- dal settore 0 a 2047, recupera i dati dal dispositivo sottostante (poiché non vogliamo interferire con la tabella delle partizioni e i metadati)
- dal settore 2048 a metà della dimensione del disco, restituisce un errore, oppure i dati originali, con una probabilità di fallimento del 20%
- da metà dimensione alla fine, restituisce nuovamente i dati dal dispositivo sottostante

La dimensione del disco può essere trovata con un semplice controllo:

```bash
# cat /sys/block/loop0/size 
2097152
```

Questo tipo di mappatura si esprime nel comando `dmsetup create`:

```bash
# dmsetup create bad_disk << EOF
0       2048    linear /dev/loop0 0
2048    1047552 flakey /dev/loop0 2048 4 1 
1049600 1047552 linear /dev/loop0 1049600
EOF

# ls -l /dev/mapper/bad_disk
lrwxrwxrwx 1 root root 7 Nov 19 17:51 /dev/mapper/bad_disk -> ../dm-0
```

Per ogni voce della tabella dobbiamo specificare:
- settore iniziale/offset della mappatura
- dimensione della mappatura 
- quale mapper utilizzare
- opzioni del mapper (per i dettagli fare riferimento alla [documentazione](https://docs.kernel.org/admin-guide/device-mapper/index.html))

In questa configurazione stiamo utilizzando il mapper [linear](https://docs.kernel.org/admin-guide/device-mapper/linear.html) e quello [flakey](https://docs.kernel.org/admin-guide/device-mapper/dm-flakey.html). Altri mapper utili possono essere [delay](https://docs.kernel.org/admin-guide/device-mapper/delay.html) per simulare dischi molto lenti o [dust](https://docs.kernel.org/admin-guide/device-mapper/dm-dust.html) che emula il comportamento dei settori danneggiati in posizioni arbitrarie, offrendo anche la possibilità di abilitare l'emulazione dei guasti in un momento arbitrario.

## Proviamolo!

Il nostro disco di supporto è già formattato, quindi è il momento di provare quello difettoso, montandolo e scrivendoci sopra dei dati:

```bash
# mkdir /mnt/bad && mount /dev/mapper/bad_disk /mnt/bad && cd /mnt/bad

# df -h | grep -E '(^Filesystem|bad)'
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/bad_disk  974M   28K  907M   1% /mnt/bad

 # while sleep 1 ; do dd if=/dev/zero of=trytowrite.bin bs=1M count=500 ; done 
500+0 records in
500+0 records out
524288000 bytes (524 MB, 500 MiB) copied, 0.595353 s, 881 MB/s
500+0 records in
500+0 records out
524288000 bytes (524 MB, 500 MiB) copied, 0.637194 s, 823 MB/s

Message from syslogd@localhost at Nov 19 18:09:15 ...
 kernel:[ 8017.117593][T23594] EXT4-fs (dm-0): failed to convert unwritten extents to written extents -- potential data loss!  (inode 13, error -30)

Message from syslogd@localhost at Nov 19 18:09:15 ...
 kernel:[ 8017.118445][T23976] EXT4-fs (dm-0): failed to convert unwritten extents to written extents -- potential data loss!  (inode 13, error -30)
dd: error writing 'trytowrite.bin': Read-only file system
481+0 records in
480+0 records out
503865344 bytes (504 MB, 481 MiB) copied, 0.549939 s, 916 MB/s
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
dd: failed to open 'trytowrite.bin': Read-only file system
```

## Il fallimento del disco è un successo!

Come possiamo vedere, all'inizio alcune operazioni di I/O vanno a buon fine, poi il disco fallisce e nel log di `dmesg` possiamo trovare maggiori dettagli:

```
[ 7962.645178] EXT4-fs (dm-0): error loading journal
[ 7979.334186] EXT4-fs (dm-0): mounted filesystem with ordered data mode. Opts: (null). Quota mode: none.
[ 8016.759602] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129024)
[ 8016.759641] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129280)
[ 8016.759685] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129536)
[ 8016.759802] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 129870)
[ 8016.760119] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 130625)
[ 8016.760122] Buffer I/O error on device dm-0, logical block 130625
[ 8016.760129] Buffer I/O error on device dm-0, logical block 130626
[ 8016.760131] Buffer I/O error on device dm-0, logical block 130627
[ 8016.760132] Buffer I/O error on device dm-0, logical block 130628
[ 8016.760133] Buffer I/O error on device dm-0, logical block 130629
[ 8016.760134] Buffer I/O error on device dm-0, logical block 130630
[ 8016.760135] Buffer I/O error on device dm-0, logical block 130631
[ 8016.760136] Buffer I/O error on device dm-0, logical block 130632
[ 8016.760137] Buffer I/O error on device dm-0, logical block 130633
[ 8016.760138] Buffer I/O error on device dm-0, logical block 130634
[ 8016.923667] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 54272)
[ 8016.923731] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 54783)
[ 8016.924020] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 55296)
[ 8016.924335] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 60416)
[ 8016.924394] EXT4-fs warning (device dm-0): ext4_end_bio:347: I/O error 10 writing to inode 13 starting block 61803)
[ 8016.961108] Buffer I/O error on dev dm-0, logical block 131103, lost sync page write
[ 8016.961125] Aborting journal on device dm-0-8.
[ 8016.961127] Buffer I/O error on dev dm-0, logical block 131072, lost sync page write
[ 8016.961128] JBD2: Error -5 detected when updating journal superblock for dm-0-8.
[ 8016.961142] EXT4-fs error (device dm-0): ext4_journal_check_start:83: comm kworker/u2:3: Detected aborted journal
[ 8016.966200] EXT4-fs error (device dm-0): ext4_journal_check_start:83: comm dd: Detected aborted journal
```
In senso più generale, questi concetti rientrano nel principio del [\"chaos engineering\"](https://en.wikipedia.org/wiki/Chaos_engineering). 
Questa può anche essere una buona esercitazione per amministratori di sistema junior che desiderano imparare ad affrontare un filesystem danneggiato e tentare di recuperare i dati.

## Pulizia

Per rimuovere le tracce dei nostri esperimenti, è sufficiente smontare il disco \"difettoso\", rimuovere la mappatura e scollegare il loop device dal file di supporto. 
```
# umount /mnt/bad && rmdir /mnt/bad
# dmsetup remove bad_disk
# losetup -d /dev/loop0
```
