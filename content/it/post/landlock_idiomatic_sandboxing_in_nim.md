---
title: "Sandboxing idiomatico con Landlock in Nim"
description: "Rafforzare la sicurezza dei programmi Linux utilizzando Linux Landlock"
date: 2026-04-09
tags: ["linux", "kernel", "LSM", "security", "nim", "systems-programming", "landlock"]
categories: ["Tutorials"]
author: "Andrea Manzini"
---

# 👋 Intro

Se hai mai passato del tempo a mettere in sicurezza le applicazioni Linux, probabilmente conosci la frustrazione del modello di permessi *tutto o niente*. Nel tipico ambiente Linux, una volta che un processo viene avviato, solitamente ha *molto più* accesso al filesystem di quanto ne abbia effettivamente bisogno. Sebbene disponiamo di strumenti come `seccomp`, `chroot` o moduli pesanti come **SELinux** e **AppArmor**, questi spesso sembrano troppo complessi per un semplice sandboxing a livello applicativo.

**Landlock** cambia questo scenario. Dal suo merge nel kernel Linux nella versione **5.13**, è diventato una svolta per gli sviluppatori. Consente a un processo di limitarsi autonomamente *senza richiedere privilegi di root*, spostando la sicurezza dalle policy di sistema globali direttamente all'interno del codice della tua applicazione.

![landlock](/img/landlock.jpg)

# ⏳ L'evoluzione di Landlock

Landlock è un'API in evoluzione che è cresciuta in modo significativo. Il kernel utilizza le **versioni ABI** per segnalare quali funzionalità sono disponibili su uno specifico sistema. Questo versionamento è cruciale perché permette alla tua sandbox di *degradare elegantemente* sui kernel più vecchi, offrendo comunque la massima sicurezza possibile su quelli moderni.

Il viaggio è iniziato con la versione **ABI v1** nel Kernel 5.13, che si concentrava sui diritti di base del filesystem come la lettura e la scrittura. Con la maturazione del progetto, la **versione 2** ha aggiunto il supporto per il reparenting dei file e la **versione 3** ha introdotto il controllo esplicito sulla troncabilità dei file. Più di recente, la **versione 4** ha introdotto il supporto di rete TCP, seguito dal controllo `ioctl` nella **versione 5** e dal controllo dell'ambito IPC (IPC scoping) nella **versione 6**. L'ultimo traguardo, la **versione 8**, ha introdotto `TSYNC`, che consente un'applicazione della sicurezza atomica (*atomic security enforcement*) su tutti i thread di un processo.

Per un elenco completo e aggiornato di queste funzionalità, puoi sempre consultare la [Documentazione ufficiale dell'API Landlock per lo Userspace](https://docs.kernel.org/userspace-api/landlock.html) o visitare il sito web del progetto su [landlock.io](https://landlock.io/).

# 🏗️ Capire l'architettura

A differenza dei tradizionali moduli di sicurezza gestiti dagli amministratori di sistema, Landlock è progettato per gli **sviluppatori di applicazioni**. È completamente *non privilegiato*, il che significa che qualsiasi processo può avviare una sandbox senza richiedere `sudo` o funzionalità (capabilities) speciali.

Il sistema è inoltre *impilabile* (stackable). Puoi applicare più livelli di regole, in cui ogni nuovo set di regole limita ulteriormente il processo. Una volta applicata una restrizione, questa **non può essere rimossa o allentata**, e ogni processo figlio generato dall'applicazione nasce automaticamente all'interno della stessa sandbox. Aspetto fondamentale, Landlock è **basato sugli oggetti** (object-based). Limita l'accesso in base alla rappresentazione interna del kernel di un file, il suo `inode`, anziché semplicemente sul suo nome. Questo lo rende intrinsecamente immune a trucchi comuni come gli *attacchi di symlink* o il *path traversal*.

Il flusso operativo segue un semplice schema a tre fasi: prima si **definisce** un set di regole per le operazioni gestite, poi si **associano** (bind) percorsi specifici del filesystem o porte di rete a tali permessi e infine si applica il set di regole (**commit**) al processo corrente.

# ⚙️ L'interfaccia del kernel

Sotto il cofano, Landlock è gestito attraverso tre syscall principali. Innanzitutto, `landlock_create_ruleset` inizializza un nuovo set di regole di sicurezza in cui si specificano le operazioni che si desidera gestire. Qualsiasi operazione non specificata rimane *non limitata*.

Successivamente, si usa `landlock_add_rule` per concedere permessi specifici a directory o porte. Attualmente, questa operazione utilizza principalmente il tipo `LANDLOCK_RULE_PATH_BENEATH` per concedere l'accesso a uno specifico albero di directory. Infine, `landlock_restrict_self` applica il set di regole al processo corrente. Prima di questa chiamata, è necessario assicurarsi che `PR_SET_NO_NEW_PRIVS` sia impostato tramite `prctl` per impedire al processo di acquisire privilegi che potrebbero aggirare la sandbox.

# 🛡️ Mitigazione pratica degli attacchi

Per comprendere il valore di questo approccio, considera un classico **attacco di path traversal** in cui un utente malintenzionato tenta di leggere `/etc/shadow` usando sequenze di `../`. Poiché Landlock applica la sicurezza a livello di `inode` del kernel, questi trucchi basati sui nomi semplicemente falliscono. Se il file non è presente nel set di regole, il kernel restituisce un errore di **Permission Denied** nell'istante esatto in cui il file viene aperto.

Questa protezione si estende anche alla rete e all'IPC. Con il **controllo dell'accesso alla rete**, a un processo compromesso può essere impedito di connettersi a server esterni di comando e controllo (C2). Abilitando il **controllo dell'ambito IPC (IPC scoping)**, è possibile impedire a un processo di inviare segnali come `SIGKILL` a qualsiasi `PID` che non faccia parte del proprio dominio di sicurezza limitato.

Oltre a questi esempi di base, Landlock fornisce una difesa robusta contro diversi altri vettori di attacco comuni:

*   **Ransomware e cifratura di massa dei file:** *Limitando rigorosamente* l'accesso in scrittura solo alle directory necessarie (como una cartella temporanea o una specifica directory di dati) e lasciando il resto del filesystem in sola lettura o inaccessibile, ai ransomware viene strutturalmente impedito di modificare o cifrare i file dell'utente.
    *   *Esempio:* Un lettore PDF all'interno di una sandbox Landlock ha solo accesso in lettura a `/home/user/Documents` e *nessun accesso in scrittura* altrove. Se il lettore viene compromesso da un PDF malevolo contenente un ransomware, questo semplicemente non potrà cifrare i tuoi file.
*   **Attacchi alla Supply Chain:** Le applicazioni moderne si affidano fortemente a dipendenze di terze parti. Se un aggiornamento malevolo in una libreria tenta di raccogliere le chiavi SSH o stabilire connessioni di rete in uscita non autorizzate, Landlock **bloccherà** l'operazione perché la sandbox dell'applicazione vieta esplicitamente tali azioni.
    *   *Esempio:* Uno script di compilazione limitato da Landlock a leggere solo `./src` e scrivere solo in `./dist`. Se un pacchetto compromesso tenta di leggere `~/.ssh/id_rsa` e aprire una connessione di rete per inviarlo a un utente malintenzionato, Landlock bloccherà entrambe le azioni.
*   **Esfiltrazione di dati:** Limitando l'accesso in lettura a posizioni sensibili (come `~/.ssh`, `~/.aws` o `/etc/shadow`) e bloccando l'accesso alla rete, gli aggressori che ottengono l'esecuzione di codice arbitrario non saranno in grado di rubare e trasmettere dati sensibili.
    *   *Esempio:* Un server web ha bisogno di accedere solo a `/var/www/html`. Se un aggressore sfrutta una vulnerabilità di **Local File Inclusion (LFI)** per cercare di leggere `/etc/passwd` o `/etc/shadow`, il kernel negherà la lettura.
*   **Escalation dei privilegi:** Poiché i set di regole di Landlock vengono ereditati da tutti i processi figli e richiedono il flag `PR_SET_NO_NEW_PRIVS`, un aggressore non può aggirare la sandbox eseguendo **eseguibili `SUID`**. Il processo figlio rimane limitato dalle *stesse identiche regole* del genitore.
    *   *Esempio:* Anche se un aggressore trova il modo di eseguire `sudo` o un altro eseguibile `SUID` root dall'interno della sandbox, il flag `PR_SET_NO_NEW_PRIVS` garantisce che il processo non elevi effettivamente i propri privilegi, rendendo l'exploit inutile.
*   **Divulgazione di informazioni e manipolazione del sistema:** I filesystem virtuali come `/proc` e `/sys` contengono una miniera di informazioni sensibili, inclusi indirizzi del kernel, configurazioni hardware e variabili d'ambiente di altri processi. Inoltre espongono endpoint scrivibili che possono modificare i parametri del kernel. Per impostazione predefinita, Landlock **limita l'accesso** a questi endpoint globali a meno che non sia esplicitamente consentito.
    *   *Esempio:* Un aggressore che sfrutta un bug in un'applicazione server potrebbe tentare di leggere `/proc/kallsyms` per aggirare la **Kernel Address Space Layout Randomization (KASLR)** o leggere `/proc/self/environ` per rubare chiavi API. Se il set di regole Landlock dell'applicazione non concede esplicitamente l'accesso a `/proc`, questi tentativi vengono immediatamente bloccati.

# 👑 Rendere Landlock idiomatico in Nim

Il nostro wrapper Nim bilancia questo controllo a basso livello con la **sicurezza ad alto livello**. Utilizziamo enum type-safe come `FsAccess`, `NetAccess` e `Scope` invece di maschere di bit grezze. Il cuore della libreria è la procedura `restrictTo`, che gestisce l'intero ciclo di vita *mascherando automaticamente i flag* che il kernel corrente non supporta.

Utilizzando la metaprogrammazione di Nim, possiamo fare un passo ulteriore. La macro `toStaticLandlock` calcola le maschere di bit del kernel a **tempo di compilazione**, sostituendo i cicli a runtime con interi letterali. Forniamo anche una DSL dichiarativa `sandbox:` che trasforma un blocco di codice leggibile in una sequenza complessa di inizializzazione.

Aspetto cruciale, `restrictTo` (e la macro `sandbox:`) restituisce un **oggetto capability `Sandboxed`** in caso di successo. Questo segue il **Witness Pattern**: richiedendo questo oggetto come argomento nelle tue procedure sensibili, crei una garanzia a tempo di compilazione che tali procedure possano essere eseguite *solo* dopo che la sandbox sia stata inizializzata correttamente.

# 💻 Esempio di implementazione

Ecco come appaiono tutti questi elementi in un'applicazione reale. Nota come `processFile` richieda il testimone (witness) `Sandboxed`, garantendo che non possa essere chiamato accidentalmente prima che le restrizioni vengano applicate.

```nim
 import landlock, os
 # This function REQUIRES proof of sandboxing
 proc processFile(proof: Sandboxed, path: string) =
   # 'proof' has no methods - it just proves we're sandboxed
   writeFile(path, "Data processed securely")
 let workDir = "/tmp/my_sandbox"
 if not dirExists(workDir): createDir(workDir)
 try:
   # 'sb' is just proof - no fields, no methods to call
   let sb = sandbox:
     allow workDir, {ReadFile, WriteFile, MakeReg}
   # The value of 'sb' is that it EXISTS - proving sandbox is active
   processFile(sb, workDir / "safe.txt")  # Compiles - we have proof
   # This won't compile - no proof available:
   # processFile(???, "file.txt")  # Error: missing Sandboxed argument
   echo "Sandboxed successfully!"
 except LandlockError as e:
   echo "Failed: ", e.msg
```   

Il tipo Sandboxed è intenzionalmente vuoto: si tratta di un pattern di sicurezza basato sulle capability. Il compilatore garantisce che il codice critico dal punto di vista della sicurezza possa essere eseguito solo se si possiede il token di prova.

# 🏁 Conclusione

Landlock e Nim rappresentano una **combinazione potente** per la creazione di sistemi sicuri. Sfruttando la metaprogrammazione, possiamo trasformare una complessa API del kernel in una garanzia statica applicata sia dal compilatore che dal kernel. È un modo pragmatico per implementare il **principle of least privilege** (principio del minimo privilegio) senza sacrificare la produttività dello sviluppatore.

Il codice completo del wrapper Nim e il Proof of Concept sono disponibili su GitHub all'indirizzo [https://github.com/ilmanzo/landlock-nim-poc](https://github.com/ilmanzo/landlock-nim-poc).

*Stay secure, stay pragmatic.*