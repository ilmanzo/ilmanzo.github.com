---
layout: post
title: "il linguaggio Lua: ottava parte"
description: "introduzione al linguaggio Lua"
category: programming
tags: [lua, programming, tutorial, linux, italian]
---
{% include JB/setup %}

segue dalla [settima parte](http://ilmanzo.github.io/programming/2018/03/03/il-linguaggio-lua-settima-parte)

## Oggetti volanti e non

Lua non è un linguaggio nativamente object-oriented. Se nei nostri script volessimo adottare uno stile OOP, ad esempio per modellare le operazioni su un conto corrente la cosa più naturale sarebbe usare una tabella:

{% highlight lua %}
Conto = { saldo = 200.0 }
{% endhighlight %}

Questa sintassi potrebbe essere assimilata al 'costruttore' dell'oggetto Conto.
Possiamo anche definire dei metodi:

{% highlight lua %}
function Conto.preleva(cifra)
  Conto.saldo = Conto.saldo - cifra
end
{% endhighlight %}

e quindi potremmo comodamente chiamare, problemi economici a parte:

{% highlight lua %}
Conto.preleva(200)
{% endhighlight %}

purtroppo, però, questa implementazione semplicistica ha il difetto di essere legata alla variabile Conto; possiamo infatti invocare il metodo solo su quella:

{% highlight lua %}
a1=Conto; Conto=nil
a1.preleva(200.0)  -- errore!
{% endhighlight %}

La soluzione consiste nell'aggiungere un ulteriore parametro al metodo, ovvero passare l'oggetto su cui operare, che in pratica è la prassi anche in altri linguaggi come Python:

{% highlight lua %}
function Conto.preleva(self,cifra)
  self.saldo = self.saldo - cifra
end
{% endhighlight %}

ora dunque siamo liberi di dare qualsiasi nome al nostro oggetto:

{% highlight lua %}
a2=Conto; Conto=nil;
a2.preleva(a2,100.0)  -- nessun errore
{% endhighlight %}

però siamo obbligati a passare sempre l'oggetto come primo parametro. Ci viene in aiuto la sintassi:

{% highlight lua %}
a2:preleva(100.0)
{% endhighlight %}

possiamo usare la stessa forma anche per definire le funzioni-metodo:

{% highlight lua %}
function Conto:deposita(cifra)
  self.saldo = self.saldo + cifra
end
{% endhighlight %}

il parametro 'nascosto' si chiamerà sempre self; altri linguaggi lo chiamano **this** ma il concetto non cambia.
Sull'argomento object oriented ci sarebbe ancora molto da dire, ma invito gli interessati a consultare il capitolo 16 di “Programming in Lua”, il libro ufficiale del quale la prima edizione è disponibile gratuitamente all'URL [http://www.lua.org/pil/16.html](http://www.lua.org/pil/16.html)