---
layout: post
title: "Sincronizzare una directory tra due server linux"
description: "Sincronizzare una directory tra due server linux"
categories: sysadmin
tags: [italiano, linux, sysadmin, debian, sync, csync2, incron]
author: Andrea Manzini
date: 2015-03-20
---

**Obiettivo**
---------
**vogliamo mantenere la stessa directory sincronizzata su due server linux.**

Questo significa che ogni aggiunta/rimozione/modifica di file in questa directory verrà automaticamente riportato sull'altro (salvo conflitti). 
Diamo per assunto che i due server siano raggiungibili via rete, ma per qualsiasi motivo non sia possibile collegare dello spazio disco condiviso. 

**Implementazione**
------------------
Per raggiungere lo scopo, utilizzeremo il tool: [csync2](http://oss.linbit.com/csync2/) 

su entrambi i server (che chiameremo nodo1 e nodo2), installiamo i pacchetti necessari:

{{< highlight bash >}}
  # apt-get install csync2 incron
{{</ highlight >}}

mentre sul primo creiamo la chiave di cifratura e il certificato che verra' usato nella connessione SSL. Notiamo che csync2 utilizza 30865/tcp per le proprie comunicazioni, per cui assicuriamoci di abilitare le connessioni in ingresso su tale porta.

{{< highlight bash >}}
  n1# csync2 -k /etc/csync2.key
  n1# openssl genrsa -out /etc/csync2_ssl_key.pem 2048
  n1# openssl req -batch -new -key /etc/csync2_ssl_key.pem -out /etc/csync2_ssl_cert.csr
  n1# openssl x509 -req -days 3600 -in /etc/csync2_ssl_cert.csr -signkey /etc/csync2_ssl_key.pem -out /etc/csync2_ssl_cert.pem
{{</ highlight >}}

creiamo il file **/etc/csync2.cfg** che conterra' le definizioni per il gruppo di sincronizzazione

<pre>
group mycluster
{
        host nodo1;
        host nodo2;
 
        key /etc/csync2.key;
 
        include /mnt/sync;
        exclude *~ .*;
}
</pre>

copiamo il tutto anche sul nodo2:
{{< highlight bash >}}
  n1# scp /etc/csync2* nodo2:/etc/
{{</ highlight >}}

per default, csync2 su debian utilizza inetd, ma e' semplice configurarlo per girare come standalone o xinetd.
dopo aver fatto partire i servizi su entrambi i nodi, possiamo usare il comando
{{< highlight bash >}}
  n1# csync2 -xv
{{</ highlight >}}
per far sì che tutte le modifiche fatte in /mnt/sync del nodo1 vengano riportate anche sul nodo2.
Per rendere la cosa automatica, potremmo schedulare un job ogni 3 minuti con *cron*:

{{< highlight bash >}}
  */3 * * * * /usr/sbin/csync2 -xv
{{</ highlight >}}

Questo e' indispensabile anche nel caso di temporaneo down o spegnimento di uno dei due sistemi; ma se preferissimo una sincronizzazione immediata , potremmo usare [*incron*](http://inotify.aiken.cz/?section=incron&page=about&lang=en)
che usando l'interfaccia *inotify*, resta in ascolto di determinati eventi su una specifica directory e al verificarsi delle condizioni desiderate, esegue il comando configurato.
Nel nostro caso, possiamo inserire nella [*incrontab*](http://linux.die.net/man/5/incrontab) una entry simile a questa:

<pre>
/mnt/sync IN_ATTRIB,IN_CREATE,IN_DELETE,IN_CLOSE_WRITE,IN_MOVE /usr/sbin/csync2 -xv
</pre>

ovvero, controlla la directory /mnt/sync e ogni volta che vengono cambiati attributi, creati, cancellati, salvati o spostati file esegui la sincronizzazione.



