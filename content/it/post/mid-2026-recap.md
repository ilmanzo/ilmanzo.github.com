---
layout: post
description: "Riepilogo di metà 2026: programmazione, conferenze e workshop sulla sicurezza"
title: "Riepilogo di metà 2026: programmazione, conferenze e workshop"
categories: conference
tags: [uyuni, opensuse, conference, flatpak, distrobox, ai, systemd, security]
author: Andrea Manzini
date: 2026-06-14
---

## 📝 In breve (TL;DR)

Siamo già a metà del 2026 e questi primi sei mesi sono stati davvero intensi. Tra scrittura di codice, conferenze e workshop in tutta Europa, ho lavorato sulla gestione dei sistemi, sul green computing, sull'IA locale e sulla sicurezza del software. Questo post è un riepilogo dei progetti e dei talk che hanno caratterizzato il mio percorso da febbraio a giugno.

---

## 🛠️ Da febbraio a maggio: approfondimento sul progetto Uyuni

Per i primi quattro mesi di quest'anno, la mia attività principale si è concentrata quasi interamente sull'affascinante mondo del progetto Uyuni. Se non avete ancora avuto l'occasione di usarlo, Uyuni è una soluzione di gestione delle infrastrutture e di configurazione incredibilmente potente e completamente open-source. Originariamente nato come evoluzione di Spacewalk, oggi rappresenta il progetto comunitario upstream che alimenta direttamente SUSE Multi-Linux Manager, precedentemente noto come SUSE Manager.

![uyuni](/img/mid2026/uyuni_logo.png)

La vera magia di Uyuni sta nella sua profonda integrazione con Salt, noto anche come SaltStack. Questa integrazione consente agli amministratori di gestire, applicare patch e configurare migliaia di macchine in tempo reale. È un vero e proprio salvavita quando si affrontano ambienti complessi e di grandi dimensioni, perché può gestire qualsiasi cosa: dalla distribuzione automatizzata dei pacchetti ai controlli di sicurezza tramite OpenSCAP. Ciò che lo rende ancora più interessante è il supporto multi-distribuzione, che permette di gestire openSUSE, SUSE Linux Enterprise, Red Hat Enterprise Linux, Rocky Linux, Debian e Ubuntu da un'unica dashboard unificata.

Oltre a tutto il lavoro su Salt e sui pacchetti, ho avuto il piacere di condurre una sessione interna di condivisione delle conoscenze su SELinux. Spesso SELinux può sembrare una specie di "magia oscura" per gli amministratori di sistema, quindi abbiamo analizzato casi reali di risoluzione dei problemi, gestione delle etichette e generazione di policy, demistificando il modo in cui protegge la nostra infrastruttura e i canali di comunicazione con i client. È stato davvero gratificante vedere i colleghi acquisire sicurezza nella gestione delle policy di sicurezza anziché limitarsi a impostare SELinux in modalità permissive.

Date un'occhiata al [sito web del progetto Uyuni](https://www.uyuni-project.org/) e alla [repository GitHub di Uyuni](https://github.com/uyuni-project/uyuni) per saperne di più.

---

## 🌿 Dal 20 al 25 aprile: SUSECON a Praga e openSUSE Developer Summit

Verso la fine di aprile, ho preparato le valigie e sono partito alla volta della splendida città di Praga per partecipare a SUSECON 2026. È stato un viaggio doppiamente speciale, perché l'openSUSE Developer Summit (noto anche come ODS 2026) si è svolto in contemporanea con la conferenza principale. Questa combinazione ha creato una fantastica sinergia in cui gli sviluppatori enterprise e i membri della community open-source hanno potuto incontrarsi, scambiarsi idee e collaborare alla prossima generazione di tecnologie Linux.

![ods](/img/mid2026/opendevsummit.png)

### Green computing e innovazione comunitaria
Tra i molti temi ispiratori discussi durante l'evento, il green computing e la sostenibilità ambientale nell'IT mi stavano particolarmente a cuore, ed erano anche il fulcro del mio talk. Con i moderni data center che consumano una quota enorme e in continua crescita dell'elettricità globale, trovare modi per rendere le nostre infrastrutture più efficienti dal punto di vista energetico è diventato un'assoluta necessità. Durante le presentazioni e nei corridoi abbiamo avuto discussioni tecniche molto approfondite su come ottimizzare tutto, dal kernel Linux ai carichi di lavoro containerizzati, per ridurre al minimo l'impronta di carbonio.

![kepler](/img/mid2026/energy-for-namespace.png)

Se volete saperne di più sull'evento, potete visitare il sito ufficiale di SUSECON 2026 all'indirizzo https://www.susecon.com/ e trovare maggiori dettagli sulla pagina dell'openSUSE Developer Summit su https://events.opensuse.org/conferences/ODS26. Ho anche caricato le slide della mia presentazione sul green computing e sull'ottimizzazione dei sistemi, che potete visualizzare [qui](https://ilmanzo.github.io/suse_presentations/green_computing_from_cli/energy_talk_en.html).

---

## 🐧 23 maggio: Linux Day SE Mantova (Flatpak e Distrobox)

A fine maggio ho avuto la splendida opportunità di tornare agli eventi delle community locali parlando al Linux Day Special Edition nella storica città di Mantova. C'è sempre qualcosa di incredibilmente speciale nei gruppi di utenti locali (LUG), e questo evento non ha fatto eccezione, pieno di utenti entusiasti, sviluppatori e appassionati di open source. Il mio talk in questa sessione si è concentrato su come modernizzare la distribuzione delle applicazioni desktop e i nostri spazi di lavoro di sviluppo usando Flatpak e Distrobox.

![ld2026se](/img/mid2026/photo_2026-06-14_10-55-41.jpg)

### Perché Flatpak + Distrobox?
Flatpak ha completamente cambiato le regole del gioco per le applicazioni desktop su Linux fornendo un formato di pacchettizzazione sicuro, isolato e indipendente dalla distribuzione. Risolve efficacemente il vecchio problema dei conflitti di dipendenze, il che significa che è possibile eseguire le ultime app desktop su qualsiasi distribuzione senza preoccuparsi di rompere le librerie di sistema. Dall'altro lato, Distrobox è uno strumento fantastico per il lavoro da riga di comando. Consente di eseguire qualsiasi distribuzione Linux all'interno del terminale utilizzando container tramite Podman o Docker. Questo significa che uno sviluppatore può eseguire senza problemi strumenti e librerie di Arch, Fedora, Debian o Ubuntu direttamente sul proprio sistema host senza intasare il sistema operativo principale.

Combinando queste due tecnologie, si ottiene un ambiente altamente flessibile e incredibilmente robusto, perfetto per i moderni sistemi operativi immutabili. Mi sono divertito moltissimo a mostrare come funzionano insieme questi strumenti, dimostrando quanto sia facile configurare un intero ambiente di sviluppo in pochi secondi.

Potete trovare maggiori informazioni sulla sede e sugli organizzatori, insieme alle slide e alle registrazioni, sulla [pagina dell'evento](https://www.lugman.org/Linux_day_2026_SE) sul sito del Linux Day Mantova.

---

## 🤖 Dal 25 al 29 maggio: Workshop AI a Norimberga

Subito dopo l'evento a Mantova, sono andato a Norimberga, in Germania, per trascorrere un'intera settimana in un workshop intensivo sull'intelligenza artificiale. Poiché i voli erano un po' complicati da incastrare, sono atterrato prima a Monaco e poi ho preso un treno panoramico per Norimberga. È stato un piacevole passaggio dal sole italiano alle verdi colline bavaresi.

Sul piano tecnico, questo workshop è stato un viaggio approfondito nell'intelligenza artificiale locale (local-first), nei modelli linguistici con pesi aperti (open-weight) e nelle sfide pratiche legate alla distribuzione di questi modelli sul proprio hardware. Abbiamo trascorso cinque giorni intensi a lavorare su diverse architetture IA all'avanguardia. Uno dei nostri principali ambiti di interesse è stato la quantizzazione dei modelli, riducendone le dimensioni con formati come GGUF ed EXL2 per poter eseguire modelli enormi da 70 miliardi di parametri su hardware di livello consumer o su piccoli server locali. Abbiamo anche dedicato molto tempo alla creazione di pipeline di ricerca di documenti a bassa latenza utilizzando la generazione aumentata da recupero, nota come RAG (Retrieval-Augmented Generation), integrata con database vettoriali ad alte prestazioni.

---

## ⚡ 6 giugno: GDG DevFest Vicenza (5+1 funzionalità di systemd da conoscere assolutamente)

All'inizio di giugno sono rimasto più vicino a casa e mi sono unito alla fantastica community del GDG DevFest Vicenza 2026, nella splendida cornice del Veneto. Sono stato invitato a tenere il talk di chiusura e ho scelto un tema a volte controverso nella community Linux: systemd. La mia presentazione si intitolava "5+1 funzionalità di systemd da conoscere assolutamente".

![devfest](/img/mid2026/dev_fest_doodled.png)

Molti sviluppatori tendono a pensare a systemd solo come a uno strumento di base per avviare e arrestare i servizi, ma in realtà racchiude una miniera di funzionalità integrate che possono sostituire molte complicate utilità esterne. Nel mio talk ho illustrato al pubblico sei dei miei trucchi preferiti. Abbiamo discusso di `systemd-socket-activate` per configurare l'avvio dei servizi su richiesta e abbiamo visto come `systemd-analyze plot` possa generare un bellissimo grafico visivo per ottimizzare i tempi di avvio del sistema. Abbiamo anche parlato dell'uso di `DynamicUser` per eseguire i servizi con utenti del tutto isolati ed effimeri a vantaggio della massima sicurezza, e di come utilizzare i file drop-in per estendere i servizi senza modificarne la configurazione principale. Infine, abbiamo visto come systemd gestisce le directory standard tramite `RuntimeDirectory` o `StateDirectory` e abbiamo parlato di `systemd-sysext`, che consente estensioni di sistema fluide e non distruttive.

Per darvi un'idea di quanto sia semplice configurare un servizio sicuro con funzionalità di sandboxing usando systemd, ecco un rapido esempio di file di servizio che abilita `DynamicUser` e imposta automaticamente directory di stato isolate:

```ini
[Unit]
Description=My secure local sandbox service

[Service]
ExecStart=/usr/bin/my-cool-app
DynamicUser=yes
StateDirectory=my-cool-app
RuntimeDirectory=my-cool-app
ProtectSystem=strict
ProtectHome=yes
```

Con queste poche righe, systemd gestisce un utente completamente effimero, isola le directory home, blocca l'accesso in scrittura al sistema e monta directory di runtime e di stato pulite per l'applicazione. L'energia alla DevFest è stata incredibile, e ho avuto ottimi scambi con sviluppatori web e mobile, sorpresi nel vedere quanto systemd potesse semplificare le loro pipeline di distribuzione. Potete visitare il sito del GDG DevFest Vicenza all'indirizzo https://devfest.gdgvicenza.it/.

---

## 🔒 Dall'8 all'11 giugno: Workshop sulla sicurezza a Helsinki

Per concludere questa intensa stagione di viaggi, ho trascorso la seconda settimana di giugno a Helsinki, in Finlandia, partecipando all'Helsinki Security Workshop. Questo evento ha riunito sistemisti, ricercatori di sicurezza e sviluppatori principali provenienti da tutta Europa.

Andare così a nord in Finlandia a giugno è stato un vero piacere, soprattutto perché siamo stati accolti da un clima estivo insolitamente caldo e piacevole. La fresca brezza proveniente dal Mar Baltico era incredibilmente rigenerante. Essendo la stagione delle famose "notti bianche" del Nord, in cui il sole quasi non tramonta e le serate rimangono luminose e radiose, avevamo a disposizione infinite ore di luce. Ne abbiamo approfittato appieno con splendide attività di squadra all'aperto.

![hels1](/img/mid2026/hels1.jpg)
![hels2](/img/mid2026/hels2.jpg)
![hels3](/img/mid2026/hels3.jpg)

---

## 🌅 Uno sguardo al futuro

Ripensando a questi primi sei mesi del 2026, mi sento grato per tutte le opportunità che ho avuto di imparare, programmare, viaggiare e scambiare idee. Questa prima metà dell'anno ha evidenziato quanto i tre pilastri dell'automazione, della sostenibilità ambientale e della sicurezza profonda siano fondamentali per il futuro del nostro settore.

Voglio rivolgere un enorme ringraziamento a tutti gli organizzatori, ai volontari, ai colleghi relatori e ai partecipanti che hanno reso questi eventi così gratificanti e memorabili. La community open-source è davvero un luogo speciale, e sono le persone a renderla così dinamica e stimolante.

Un ringraziamento speciale va ad alcune delle community locali che hanno reso quest'anno memorabile. È stato fantastico collaborare e scambiare idee con gli amici di [GDG Vicenza](https://gdg.community.dev/gdg-vicenza/), [GDG Venezia](https://gdg.community.dev/gdg-venezia/), [BacaroTech](https://bacarotech.github.io/) e [Mantova Dev](https://linktr.ee/mantovadev), oltre a partecipare alla bellissima iniziativa [copiaIncolla Open](https://www.copiaincolla.com/copiaincolla-open). Questi gruppi locali sono il vero cuore pulsante dell'open source, e l'energia, la curiosità e il calore che portano in ogni singolo incontro e discussione sono incredibilmente stimolanti.

Ora che la stagione primaverile delle conferenze si è conclusa, ho in programma di tornare alla mia scrivania per dedicare del tempo prezioso a scrivere codice e fare esperimenti.

***

### Partecipa alla conversazione!

Mi piacerebbe molto conoscere le vostre esperienze e idee su questi argomenti. Parliamone nella sezione dei commenti qui sotto:

* **Modelli IA locali:** Avete provato a eseguire modelli linguistici di grandi dimensioni in locale sul vostro computer? Quali sono i vostri strumenti e formati di quantizzazione preferiti?
* **Ambiente di sviluppo:** Usate Flatpak o Distrobox nei vostri flussi di lavoro quotidiani? Come ha influito sulla stabilità del vostro ambiente?
* **Funzionalità avanzate di systemd:** Sfruttate le funzionalità avanzate di systemd come `DynamicUser` o `sysext` nei vostri servizi, o lo considerate ancora un semplice gestore di servizi di base?

Se preferite, potete anche contattarmi direttamente su [Mastodon](https://fosstodon.org/@ilmanzo) per condividere feedback o fare domande. Continuiamo la nostra conversazione sull'open source!