---
layout: post
title: "il linguaggio Lua: prima parte"
description: "introduzione al linguaggio Lua"
category: programming
tags: [lua, programming, tutorial]
---
{% include JB/setup %}

#introduzione

Ho sempre avuto un debole per il software leggero e snello: sara' un retaggio di quando la memoria si misurava in Kb e lo storage era basato su... audiocassette! [Lua](https://www.lua.org/) e' un linguaggio che incarna questa filosofia: occupa circa un centinaio di kbyte (meno di molte pagine web), ha una stupefacente rapidita' di esecuzione, una sintassi chiara e, come bonus, gira su qualsiasi CPU per cui sia disponibile un compilatore C.


#'Dalla terra alla luna', ovvero breve storia di Lua
Per capire da dove viene questo gioiellino, facciamo qualche passo indietro nel tempo...

Nel 1992, all'universita' cattolica pontificia di Rio de Janeiro, un gruppo specializzato in computer graphics chiamato Tecgraf sta sviluppando interfacce interattive nel settore dell'elaborazione dati per l'industria petrolifera. 

Tra il 1977 ed il 1992 il Brasile attraversa un difficile periodo di embargo politico e difficolta' economiche, percio' spesso per istituti ed enti non è possibile comprare all'estero
pacchetti software aggiornati o personalizzati, l'unica soluzione e' fabbricarsi gli strumenti "in casa". 

Allo scopo di  aggiungere un minimo di flessibilita' ad alcune procedure, nacquero quindi SOL (Simple Object Language) e DEL (Data Entry Language).  Ebbero un discreto successo nel settore, ma dato che non avevano strutture di controllo e l'azienda committente richiedeva maggiore capacita' di intervento, nacque l'esigenza di utilizzare un linguaggio unificato e completo, ma abbastanza semplice da essere alla portata anche di tecnici senza grandi conoscenze di programmazione.

Al tempo l'unico candidato era [Tcl](https://www.tcl.tk/) (Python era ancora immaturo), ma aveva una sintassi poco familiare e soprattutto girava solo sulle costose workstation UNIX. [Roberto Lerusalimschy, Luiz Henrique de Figueiredo e Waldemar Celes](http://www.lua.org/authors.html) avevano bisogno di un linguaggio portabile, semplice e facile da integrare: nel 1993 nasce **Lua** che, attraverso varie revisioni e aggiustamenti anche sostanziali, arriva ai giorni nostri. 

Il progetto ormai e' piuttosto stabile: Lua 4.0 fu rilasciato nel 2000 e presentava praticamente le stesse caratteristiche della versione che conosciamo ed installiamo oggi.

Essendo nato come linguaggio ausiliario (o, meglio, satellite), Lua e' ideale per aggiungere capacita' di scripting in grossi progetti. Benche' sia nato in un'universita', è tutto fuorche' un linguaggio accademico, pieno di feature o utilizzato solo da chi scrive trattati teorici: Lua punta alla sostanza e lo si vede già dalla [licenza (MIT) con cui e' distribuito](http://www.lua.org/license.html), la stessa di software diffusi come X Window System, Ruby on Rails e Mono.

#'lo stolto guarda il dito'
Ovviamente la prima domanda che vi frullera' in testa sara': perché dovrei usare Lua e non Perl o Ruby o  Tcl o Python o Javascript o PHP? Ecco 7 motivi:

- Lua e' molto piccolo: basta linkare al progetto una libreria di 150kb. Altri linguaggi hanno esigenze ben diverse;

- e' secure by default: l'interprete gira in una sandbox e gli unici punti di contatto con l'applicazione principale sono quelli che decidiamo noi. Persino le istruzioni di I/O (inclusa la *print*) sono opzionali;

- è velocissimo: nei benchmark batte qualsiasi linguaggio interpretato e la versione Just-In-Time e' paragonabile a quelli compilati;

- e' semplice: la sintassi conta una ventina di operatori ed altrettante parole chiave, puo' impararlo facilmente anche chi non sviluppa per professione;

- e' flessibile: ha tipizzazione dinamica, e' facile da integrare con librerie esterne e, disponendo di un ampio parco di utilizzatori, troviamo disponibili sulla rete moduli per praticamente qualsiasi esigenza (per avere un'idea visitiamo [http://luaforge.net](http://luaforge.net);

- e' open source e, grazie alla permissiva licenza MIT, non c'e' nessun problema ad includerne versioni modificate nei vostri progetti senza dover per forza rilasciare i sorgenti;

- e' maturo e stabile (ha quasi vent'anni di storia), ma e' anche moderno, tecnicamente parlando: Lua ha un garbage collector mark-and-sweep, che funziona in modo incrementale. Ha caratteristiche dei linguaggi funzionali come closure lessicali e ottimizza le tail calls. Come vedremo, le funzioni sono tipi di prima classe.


Vi ho convinti? E allora andiamo avanti al passo successivo.

# 'Fly me to the moon' ovvero: installazione
Data la sua diffusione, ci sono grandi probabilita' che nel nostro PC Lua sia gia' installato, ma per levarci lo sfizio, sulla classica Debian/Ubuntu basta un:

{% highlight bash %}

$ sudo apt-get install lua5.2 luajit

{% endhighlight %}

luajit e' la versione *turbo*, che esegue gli stessi programmi, ma con una tecnica diversa: trasla le istruzioni in codice macchina nativo con risultati eccellenti.
Per chi preferisse usare i sorgenti, e' sufficiente scaricare e scompattare un tarball:

{% highlight bash %}

$ curl http://www.lua.org/ftp/lua-5.3.2.tar.gz | tar xz

{% endhighlight %}

per poi compilare per piattaforma Linux ed installare come superuser i binari ottenuti:

{% highlight bash %}

$ cd lua-5.3.2 ; make linux && sudo make install

{% endhighlight %}

Una volta installato il software, proviamo a scrivere il nostro primo programma Lua! Eseguiamo l'interprete interattivo a linea di comando, una specie di *lua shell*:

{% highlight bash %}

$ lua

{% endhighlight %}


subito dopo vedremo una riga con le informazioni di rito; al prompt che appare scriviamo:

{% highlight lua %}

> print "Hello, World!"

{% endhighlight %}

il risultato e' quello che ci aspettiamo. Non e' un granche' come programma... Ma tutti i grandi hanno iniziato in questo modo! Per uscire, basta un CTRL-C o CTRL-D.
Facciamo un passo avanti e scriviamo uno script vero e proprio. Apriamo un editor di testo e digitiamo queste righe:

{% highlight lua %}

for i=1,10 do
  print("ciclo numero",i)
end

{% endhighlight %}

salviamo come script1.lua e possiamo eseguirlo da shell:

{% highlight bash %}

$ lua script1.lua

{% endhighlight %}

Da questo esempio impariamo la sintassi del ciclo for 'numerico' ed osserviamo che nelle chiamate a funzione (print e' una funzione della libreria di sistema) se ci sono piu' parametri dobbiamo usare le parentesi tonde per delimitare gli argomenti. A tal proposito possiamo consultare la [FAQ](http://www.luafaq.org/gotchas.html#T7).


Lua permette anche la precompilazione: se vogliamo evitare di distribuire i sorgenti, possiamo conservare sul disco solo la versione bytecode del nostro programma; invocando Lua Compiler:


{% highlight bash %}

$ luac -o script1.luac script1.lua

{% endhighlight %}

troveremo nella directory un nuovo file binario; lo possiamo eseguire allo stesso modo del precedente:

{% highlight bash %}

$ lua script1.luac

{% endhighlight %}

e ovviamente otteniamo gli stessi risultati. Potremmo anche usare l'opzione -s per rimuovere i simboli di debug dal compilato.


Ora che il linguaggio e' installato e funzionante, cominceremo ad approfondirne i dettagli; questo non potra' essere un "corso di programmazione Lua" completo, ma cercheremo di evidenziare gli aspetti principali, rimandando alla documentazione ufficiale per gli indispensabili approfondimenti.



