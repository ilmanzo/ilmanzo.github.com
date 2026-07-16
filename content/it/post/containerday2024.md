---
layout: post
description: "Punti salienti della conferenza italiana ContainerDay 2024"
title: "Resoconto del ContainerDay 2024"
categories: conference
tags: [containers, kubernetes, k8s, cncf, cloud, SUSE, conference]
author: Andrea Manzini
date: 2024-10-11
---

## Introduzione

Il [Container Day](https://2024.containerday.it/index.html) italiano è una conferenza annuale organizzata da [GRUSP](https://www.grusp.org/en/) con focus sulle tecnologie cloud native e container, sugli strumenti devops e sulle relative best practice. La sede scelta per quest'anno è stata un [piacevole hotel a Bologna](https://www.savoia.eu/), un'ottima scelta e in una zona d'Italia molto accessibile (grazie ai vicini collegamenti autostradali e ferroviari).

![badge](/img/containerday_2024/IMG_20241010_202216.jpg)

## Il programma

- Intro by GrUSP
- Navigating the CNCF Landscape, one step at a time ([Sara Trappetti](https://github.com/SaraTrap), [Michel Murabito](https://github.com/akelity))
- PlatformOps with Crossplane: how to build your next-gen Kubernetes-based platform ([Daniele Monti](https://github.com/Monska85))
- Introduction of logs in OpenTelemetry: features and opportunities ([Martino Fornasa](https://www.linkedin.com/in/fornasa/))
- My first monitoring with EBPF ([Gabriele Santomaggio](https://github.com/Gsantomaggio/))
- Reimagine the Multi-Cluster ([Francesco Torta](https://github.com/fra98), [Guido Ricioppo](https://github.com/guidonguido))
- .Net Aspire - how to develop and forget about container ([Mattia Muraro](https://github.com/mattiamuraro))
- Improve your container management with Event-Driven Ansible ([Fabio Alessandro Locati](https://fale.io/))
- Leaving no Leaf Device Behind: at the Edge Computing frontier with Akri ([Luca Barzè](https://www.linkedin.com/in/barze/))
- Containers: the last opportunity to make reproducible AI ([Marco Franzon](https://github.com/mfranzon))
- 👋 Conference closing

![foundations](/img/containerday_2024/IMG_20241010_103454.jpg)

## Alcuni punti salienti personali

**Monitoraggio con eBPF: una svolta nell'osservabilità**
Una delle presentazioni di spicco è stata "My first monitoring with eBPF" di Gabriele Santomaggio. Questo talk ha illustrato la potenza di eBPF (extended Berkeley Packet Filter) nel rivoluzionare il modo in cui affrontiamo il monitoraggio del sistema e l'osservabilità.
Punti chiave:

- La capacità di eBPF di fornire approfondimenti dettagliati sulle operazioni a livello di kernel
- Come consenta un monitoraggio in tempo reale e con un sovraccarico (overhead) ridotto
- Applicazioni pratiche nel tuning delle prestazioni e nella sicurezza

**PlatformOps con Crossplane: costruire piattaforme Kubernetes di prossima generazione**
La presentazione di Daniele Monti su *"PlatformOps with Crossplane"* è stata un altro punto di forza. Ha spiegato come Crossplane stia cambiando le regole del gioco nell'ingegneria delle piattaforme basate su Kubernetes.
Punti chiave:

- Il ruolo di Crossplane nell'astrarre l'infrastruttura complessa
- Come abiliti un approccio più dichiarativo alla gestione delle risorse multi-cloud
- Il potenziale per snellire i workflow DevOps

![quote](/img/containerday_2024/IMG_20241010_120831.jpg)

**.NET Aspire: semplificare lo sviluppo di container**
Il talk di Mattia Muraro su ".NET Aspire - how to develop and forget about containers" è stato illuminante. Ha mostrato gli ultimi sforzi di Microsoft per semplificare lo sviluppo cloud-native per gli sviluppatori .NET.
Intuizioni:

- L'approccio di Aspire nell'astrarre le complessità dei container
- Come si integri con gli ecosistemi .NET esistenti
- Potenziale impatto sulla produttività degli sviluppatori e sulla scalabilità delle applicazioni

**Le frontiere dell'Edge Computing con Akri**
La presentazione di Luca Barzè, "Leaving no Leaf Device Behind: at the Edge Computing frontier with Akri", è stata particolarmente intrigante. Ha evidenziato la crescente importanza dell'edge computing nell'IoT e nei sistemi distribuiti.
Punti chiave:

- Il ruolo di Akri nella scoperta e nell'utilizzo dei dispositivi edge
- Come colmi il divario tra Kubernetes e l'edge
- Potenziali applicazioni nell'IoT, nell'automazione industriale e altro ancora

![akri](/img/containerday_2024/IMG_20241010_162023.jpg)

## Conclusioni

Sebbene le presentazioni tecniche siano state di valore inestimabile, e la varietà degli argomenti trattati abbia messo in evidenza il ritmo incalzante dell'innovazione nelle tecnologie cloud native, la conferenza ha offerto molto più di un semplice apprendimento strutturato. È stata un'ottima occasione di networking e di scambio di conoscenze. Ho avuto la possibilità di ritrovare volti noti del settore e di incontrare nuovi professionisti del campo. Sia gli speaker che i partecipanti hanno mostrato una passione e una competenza incredibili. Queste interazioni personali e i momenti condivisi di scoperta sono stati, per molti versi, il cuore dell'esperienza della conferenza.

Infine, un plauso agli organizzatori per il sistema interattivo di codici QR: ogni presentazione includeva un codice QR che rimandava a un sito web dedicato per domande e feedback in tempo reale. Questo approccio innovativo ha snellito le sessioni di domande e risposte (Q&A), sia per i partecipanti in presenza che da remoto, migliorando il colvolgimento del pubblico e assecondando le preferenze per la comunicazione scritta, dimostrando un uso efficace della tecnologia da parte della conferenza per migliorare i risultati dell'apprendimento.

In particolare, [SUSE](https://www.suse.com) era uno degli sponsor, quindi ho avuto la possibilità di incontrare alcuni colleghi allo stand aziendale 🤓

![sponsors](/img/containerday_2024/IMG_20241010_090527.jpg)
