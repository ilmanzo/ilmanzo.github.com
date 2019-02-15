---
layout: post
title: "il linguaggio Lua: parte 14"
description: "introduzione al linguaggio Lua"
category: programming
tags: [lua, programming, tutorial, linux, italian]
---
{% include JB/setup %}

segue dalla [parte 13](http://ilmanzo.github.io/programming/2019/01/19/il-linguaggio-lua-13)

# Coroutine

Come approccio alla programmazione concorrente, il linguaggio Lua non ha meccanismi interni per gestire nativamente i thread, ma si può appoggiare a ciò che offre il sistema operativo sottostante. Lua invece internamente offre il supporto alle coroutine: un programma Lua può avere diversi percorsi di esecuzione parallela ognuno col proprio stack e variabili locali ma che condividono risorse e variabili globali con le altre coroutine. 

La prima differenza sostanziale col modello classico dei thread è che in un determinato istante 'gira' una e una sola coroutine, mentre in un sistema multiprocessore ci possono essere più thread in esecuzione. 

La seconda grande differenza è che nei thread c'è una entità esterna (di solito lo scheduler del il sistema operativo) che sovrintende all'ordine e assegna la 'fetta' di processore a disposizione di ciascun thread, mentre in Lua ciascuna coroutine decide quando è il momento di “sospendersi” per lasciare la cpu alle altre. 

In questo caso, si parla infatti di cooperative multitasking. Le ragioni di questa scelta degli autori sono molteplici: anzitutto la semplicità di implementazione, poi ricordiamo il fatto che Lua è nato come linguaggio 'embedded', perciò qualora ci fosse veramente bisogno dei thread si sfrutteranno le capacità del linguaggio ospitante.

Le funzionalità per gestire le coroutine in Lua sono raggruppate nel package *'coroutine'*. La prima funzione che serve è la create, che riceve come unico argomento una funzione e ritorna un valore di tipo thread:

{% highlight lua %}
>co=coroutine.create(function () print “ciao” end)
>print(co)
thread: 0x8408068
{% endhighlight %}

una coroutine può avere tre stati: suspended, running, dead. Una coroutine appena creata è in stato *suspended*:

{% highlight lua %}
>print(coroutine.status(co))
suspended
{% endhighlight %}

quindi per avviarla chiamiamo *.resume* :

{% highlight lua %}
>coroutine.resume(co)
ciao
{% endhighlight %}

ora la routine è terminata:

{% highlight lua %}
>print(coroutine.status(co))
dead
{% endhighlight %}

ogni coroutine può volontariamente *'mettersi in pausa'* e passare alcuni valori tramite la funzione **yield** ; vediamo un semplice esempio:

{% highlight lua %}
NTHREADS=20

function ping()
 print "ping"
 coroutine.yield()
end

function pong()
  print "pong"
  coroutine.yield()
end

threads={}
for j=1,NTHREADS do 
  if j%2==0 then
    threads[j]=coroutine.create(pong)
  else
    threads[j]=coroutine.create(ping)
  end
end
  
running=true
while running do
  for j=1,NTHREADS do
    running=coroutine.resume(threads[j])
  end
end
{% endhighlight %}


se volessimo invece sfruttare i thread del sistema operativo, si possono utilizzare librerie come [Lanes](https://luarocks.org/modules/benoitgermain/lanes) oppure [llthreads2](https://luarocks.org/modules/moteus/lua-llthreads2) .


