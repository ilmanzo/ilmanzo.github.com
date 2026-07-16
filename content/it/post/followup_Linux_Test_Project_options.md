---
layout: post
title: "Linux Test Project parte 2"
description: "Approfondimento su LTP: le opzioni di test"
categories: linux
tags: [linux, sysadmin, opensuse, test, kernel, syscalls]
author: Andrea Manzini
date: 2024-10-27
---

## 👻 Introduzione

Mentre il nostro [post precedente](https://ilmanzo.github.io/it/post/first_steps_of_ltp_linux_test_project/) si concentrava sui componenti principali dei test LTP, oggi in questa seconda parte faremo un'immersione incredibilmente profonda nelle opzioni disponibili in `struct tst_test` 🦇.

Il [Linux Test Project (LTP)](https://github.com/linux-test-project/ltp) è nato come uno sforzo collaborativo tra SGI, OSDL e Bull. Oggi vive grazie ai contributi congiunti di leader del settore come IBM, Cisco, Fujitsu, SUSE, Red Hat, Oracle e altri. La sua missione rimane chiara: fornire alla community open source test completi che verifichino l'affidabilità, la robustezza e la stabilità di Linux. 🕸️

## 🍭 Meno chiacchiere, mostrami il codice

La struct stessa è piuttosto ben commentata, quindi evidenzieremo le parti più importanti. Per il resto, consultate la [documentazione](https://linux-test-project.readthedocs.io/en/latest/developers/api_c_tests.html#struct-tst-test)

{{< highlight C "linenos=table">}}
struct tst_test {
    unsigned int tcnt;
    struct tst_option *options;
    const char *min_kver;
    const char *const *supported_archs;
    const char *tconf_msg;
    unsigned int needs_tmpdir:1;
    unsigned int needs_root:1;
    unsigned int forks_child:1;
    unsigned int needs_device:1;
    unsigned int needs_checkpoints:1;
    unsigned int needs_overlay:1;
    unsigned int format_device:1;
    unsigned int mount_device:1;
    unsigned int needs_rofs:1;
    unsigned int child_needs_reinit:1;
    unsigned int runs_script:1;
    unsigned int needs_devfs:1;
    unsigned int restore_wallclock:1;
    unsigned int all_filesystems:1;
    unsigned int skip_in_lockdown:1;
    unsigned int skip_in_secureboot:1;
    unsigned int skip_in_compat:1;
    int needs_abi_bits;
    unsigned int needs_hugetlbfs:1;
    const char *const *skip_filesystems;
    unsigned long min_cpus;
    unsigned long min_mem_avail;
    unsigned long min_swap_avail;
    struct tst_hugepage hugepages;
    unsigned int taint_check;
    unsigned int test_variants;
    unsigned int dev_min_size;
    struct tst_fs *filesystems;
    const char *mntpoint;
    int max_runtime;
    void (*setup)(void);
    void (*cleanup)(void);
    void (*test)(unsigned int test_nr);
    void (*test_all)(void);
    const char *scall;
    int (*sample)(int clk_id, long long usec);
    const char *const *resource_files;
    const char * const *needs_drivers;
    const struct tst_path_val *save_restore;
    const struct tst_ulimit_val *ulimit;
    const char *const *needs_kconfigs;
    struct tst_buffers *bufs;
    struct tst_cap *caps;
    const struct tst_tag *tags;
    const char *const *needs_cmds;
    const enum tst_cg_ver needs_cgroup_ver;
    const char *const *needs_cgroup_ctrls;
    int needs_cgroup_nsdelegate:1;
};
{{< / highlight >}}

## 

- linea 2: questo è il numero di test contenuti nel programma. Se state utilizzando un approccio data-driven con molti casi di test in un array, questo numero dovrà essere uguale alla dimensione dell'array.

- linea 3: un puntatore a una lista di opzioni terminata da null (TODO)

- linea 4: una stringa che descrive la versione minima del kernel necessaria per questo test. Quando viene eseguito su una versione precedente, LTP escluderà automaticamente questo test con un messaggio appropriato.

- linea 5: Un array terminato da NULL di architetture su cui viene eseguito il test, ad esempio {"x86_64", "x86", NULL}.

- linea 6: Se impostato, il test esce con TCONF subito dopo essere entrato nella libreria di test. Questo viene utilizzato dalla macro TST_TEST_TCONF() per disabilitare i test a tempo di compilazione.

- linee 7-23: insieme di flag booleani che abilitano comportamenti specifici di LTP. Ad esempio, se `needs_tmpdir` è `true`, LTP creerà automaticamente una directory temporanea per i dati del nostro programma.

- linee 24-36: insieme di opzioni che controllano se il test debba essere eseguito o meno. Ad esempio, se `min_cpus=2`, il test non verrà eseguito su sistemi single-core.

- linee 37-38: puntatori alle funzioni di `setup` and `cleanup` che verranno chiamate solo una volta, prima e dopo l'esecuzione del test.

- linee 39-40: puntatori mutuamente esclusivi al codice di test vero e proprio. Il primo accetta un numero intero, utile quando si hanno molti casi di test per la stessa funzione. Se il test contiene un solo caso, si può usare il secondo. 

- linee 41-42: riservate per uso interno.

- linea 43: Un array terminato da NULL di nomi di file che verranno copiati nella directory temporanea del test dalla directory dei file di dati di LTP.

- linea 48: Una descrizione dei buffer protetti (guarded buffers) da allocare per il test. I buffer protetti sono buffer con una pagina "avvelenata" (poisoned page) allocata subito prima dell'inizio del buffer e un canarino (canary) subito dopo la fine del buffer. Vedere struct tst_buffers e tst_buffer_alloc() per i dettagli.

## 🍬 Basta trucchi, voglio un dolcetto  

Per vedere l'uso reale di queste opzioni, analizziamo uno dei test. Prendiamone uno semplice come la syscall [swapoff](https://man7.org/linux/man-pages/man2/swapon.2.html); più che al test in sé, siamo interessati all'uso di `struct tst_test`, ma il sorgente è piuttosto breve e leggere il codice è sempre educativo. È una delle quattro libertà essenziali del Software Libero, non è vero?

```bash
# cat ltp/testcases/kernel/syscalls/swapoff/swapoff01.c
```
{{< highlight C "linenos=table">}}
// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) Wipro Technologies Ltd, 2002.  All Rights Reserved.
 */

/*\
 * [Description]
 *
 * Check that swapoff() succeeds.
 */

#include <unistd.h>
#include <errno.h>
#include <stdlib.h>

#include "tst_test.h"
#include "lapi/syscalls.h"
#include "libswap.h"

#define MNTPOINT	"mntpoint"
#define TEST_FILE	MNTPOINT"/testswap"
#define SWAP_FILE	MNTPOINT"/swapfile"

static void verify_swapoff(void)
{
	if (tst_syscall(__NR_swapon, SWAP_FILE, 0) != 0) {
		tst_res(TFAIL | TERRNO, "Failed to turn on the swap file"
			 ", skipping test iteration");
		return;
	}

	TEST(tst_syscall(__NR_swapoff, SWAP_FILE));

	if (TST_RET == -1) {
		tst_res(TFAIL | TTERRNO, "Failed to turn off swapfile,"
			" system reboot after execution of LTP "
			"test suite is recommended.");
	} else {
		tst_res(TPASS, "Succeeded to turn off swapfile");
	}
}

static void setup(void)
{
	is_swap_supported(TEST_FILE);
	SAFE_MAKE_SWAPFILE_BLKS(SWAP_FILE, 65536);
}

static struct tst_test test = {
	.mntpoint = MNTPOINT,
	.mount_device = 1,
	.dev_min_size = 350,
	.all_filesystems = 1,
	.needs_root = 1,
	.test_all = verify_swapoff,
	.max_runtime = 60,
	.setup = setup
};
{{< / highlight >}}

- linee 1-18: licenza standard e inclusione degli header file di LTP.
- linee 20-22: definizione di alcuni valori costanti che verranno utilizzati nel test.
- linee 24-41: la funzione di test vera e propria. Questa funzione in sostanza chiama `swapon()` per creare un file di swap (interrompendo in caso di fallimento), quindi tenta di disattivare lo swap su quel file verificando il risultato.
- linee 43-47: la funzione `setup()`, eseguita una sola volta prima dell'inizio del test: verifica se il sistema supporta lo swap, quindi crea un piccolo file di swap utilizzando funzioni di supporto.
- linea 49: la definizione dei parametri `tst_test` per questo test:
- linea 50: il test richiede un nuovo mountpoint: LTP si occuperà di crearlo e distruggerlo alla fine.
- linea 51: LTP formatta il dispositivo e lo monta nel mountpoint specificato sopra.
- linea 52: il dispositivo deve avere una dimensione minima di 350MB.
- linea 52: rileva tutti i filesystem supportati dal kernel e ripete automaticamente lo stesso test per TUTTI.
- linea 53: questo test deve essere eseguito come root. Se eseguito come utente normale, il codice di uscita sarà TCONF.
- linea 54: puntatore alla funzione di test vera e propria.
- linea 55: assegna 60 secondi per l'esecuzione di questo test. Se superati, LTP contrassegnerà automaticamente questo test con un errore.
- linea 56: puntatore alla funzione di setup.

## 🦸 Corri corri corri
Eseguiamo questo test su una macchina virtuale [openSUSE](https://www.opensuse.org/):

```bash
# cd ltp/testcases/kernel/syscalls/swapoff
# make swapoff01
# ./swapoff01 
tst_tmpdir.c:316: TINFO: Using /tmp/LTP_swaGg5kZE as tmpdir (tmpfs filesystem)
tst_device.c:96: TINFO: Found free device 0 '/dev/loop0'
tst_test.c:1888: TINFO: LTP version: 20240930-44-g34e6dd2d2
tst_test.c:1892: TINFO: Tested kernel: 6.4.0-slfo.1.7-default #1 SMP PREEMPT_DYNAMIC Tue Oct  1 10:57:21 UTC 2024 (0e26fa9) x86_64
tst_test.c:1723: TINFO: Timeout per run is 0h 01m 30s
tst_supported_fs_types.c:97: TINFO: Kernel supports ext2
tst_supported_fs_types.c:62: TINFO: mkfs.ext2 does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports ext3
tst_supported_fs_types.c:62: TINFO: mkfs.ext3 does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports ext4
tst_supported_fs_types.c:62: TINFO: mkfs.ext4 does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports xfs
tst_supported_fs_types.c:58: TINFO: mkfs.xfs does not exist
tst_supported_fs_types.c:97: TINFO: Kernel supports btrfs
tst_supported_fs_types.c:62: TINFO: mkfs.btrfs does exist
tst_supported_fs_types.c:105: TINFO: Skipping bcachefs because of FUSE blacklist
tst_supported_fs_types.c:97: TINFO: Kernel supports vfat
tst_supported_fs_types.c:62: TINFO: mkfs.vfat does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports exfat
tst_supported_fs_types.c:58: TINFO: mkfs.exfat does not exist
tst_supported_fs_types.c:132: TINFO: FUSE does support ntfs
tst_supported_fs_types.c:62: TINFO: mkfs.ntfs does exist
tst_supported_fs_types.c:97: TINFO: Kernel supports tmpfs
tst_supported_fs_types.c:49: TINFO: mkfs is not needed for tmpfs
tst_test.c:1821: TINFO: === Testing on ext2 ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ext2 opts='' extra opts=''
mke2fs 1.47.0 (5-Feb-2023)
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ext2 flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on ext3 ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ext3 opts='' extra opts=''
mke2fs 1.47.0 (5-Feb-2023)
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ext3 flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on ext4 ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ext4 opts='' extra opts=''
mke2fs 1.47.0 (5-Feb-2023)
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ext4 flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on btrfs ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with btrfs opts='' extra opts=''
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=btrfs flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
libswap.c:43: TINFO: FS_NOCOW_FL attribute set on mntpoint/testswap
tst_ioctl.c:21: TINFO: FIBMAP ioctl is NOT supported: EINVAL (22)
libswap.c:128: TINFO: File 'mntpoint/testswap' is not contiguous
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
libswap.c:43: TINFO: FS_NOCOW_FL attribute set on mntpoint/swapfile
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on vfat ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with vfat opts='' extra opts=''
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=vfat flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on ntfs ===
tst_test.c:1171: TINFO: Formatting /dev/loop0 with ntfs opts='' extra opts=''
The partition start sector was not specified for /dev/loop0 and it could not be obtained automatically.  It has been set to 0.
The number of sectors per track was not specified for /dev/loop0 and it could not be obtained automatically.  It has been set to 0.
The number of heads was not specified for /dev/loop0 and it could not be obtained automatically.  It has been set to 0.
To boot from a device, Windows needs the 'partition start sector', the 'sectors per track' and the 'number of heads' to be set.
Windows will not be able to boot from this device.
tst_test.c:1183: TINFO: Mounting /dev/loop0 to /tmp/LTP_swaGg5kZE/mntpoint fstyp=ntfs flags=0
tst_test.c:1183: TINFO: Trying FUSE...
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:26: TINFO: FIBMAP ioctl is supported
swapoff01.c:46: TINFO: create a swapfile with 65536 block numbers
swapoff01.c:39: TPASS: Succeeded to turn off swapfile
tst_test.c:1821: TINFO: === Testing on tmpfs ===
tst_test.c:1171: TINFO: Skipping mkfs for TMPFS filesystem
tst_test.c:1147: TINFO: Limiting tmpfs size to 350MB
tst_test.c:1183: TINFO: Mounting ltp-tmpfs to /tmp/LTP_swaGg5kZE/mntpoint fstyp=tmpfs flags=0
libswap.c:198: TINFO: create a swapfile size of 1 megabytes (MB)
tst_ioctl.c:21: TINFO: FIBMAP ioctl is NOT supported: EINVAL (22)
libswap.c:228: TCONF: Swapfile on tmpfs not implemented

Summary:
passed   6
failed   0
broken   0
skipped  1
warnings 0
```

Come si può notare, lo sviluppatore del test deve preoccuparsi solo di verificare la specifica caratteristica o funzionalità, mentre tutto il codice di contorno (boilerplate) è gestito dal framework LTP e dalle sue funzioni di utilità. Molto comodo!

## 🎃 Conclusioni (?)

Se siete interessati al progetto LTP, date un'occhiata al [repository del progetto](https://github.com/linux-test-project/ltp) per ulteriore documentazione e per le linee guida di scrittura (Writing Guidelines); potete anche iscrivervi alla [Mailing List di LTP](https://lists.linux.it/listinfo/ltp). 

Se vi piace questo tipo di post di approfondimento e ne volete altri, o per qualsiasi altro feedback, non esitate a scrivermi un messaggio via email o su [fosstodon](https://fosstodon.org/@ilmanzo). Buon divertimento!
