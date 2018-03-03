---
layout: post
title: "il linguaggio Lua: settima parte"
description: "introduzione al linguaggio Lua"
category: programming
tags: [lua, programming, tutorial, linux, italian]
---
{% include JB/setup %}

segue dalla [sesta parte](http://ilmanzo.github.io/programming/2017/12/22/il-linguaggio-lua-sesta-parte)

# Iteratori e lua funzionale

Cos'è un iteratore? Informaticamente parlando, è un costrutto che ci permette di scorrere strutture dati come liste, array, elenchi. In pratica, dato un elemento della struttura il compito dell'iteratore è farci avere il prossimo su cui operare. Non ci stupirà apprendere che in Lua gli iteratori sono funzioni. Vediamo un semplice esempio:

{% highlight lua %}
function reverse_iter(t)
  local i=#t+1
  return function()
    i=i-1
    if i>=0 then return t[i] end
  end
end
{% endhighlight %}

reverse_iter è una fabbrica (factory) di funzioni: ogni volta che la chiamiamo, ci crea una nuova closure, ossia l'iteratore specifico per l'array che gli passiamo. La funzione che otteniamo mantiene il suo stato grazie alle variabili i e t ; quando non ci sono più elementi, restituisce nil.
L'iteratore si potrebbe usare così:

{% highlight lua %}
lista={10,20,30,40}
iteratore = reverse_iter(lista)
> print(iteratore())
40
> print(iteratore())
30
> print(iteratore())
20
> print(iteratore())                                                                                                                                                                                                 
10                                                                                                                                                                                                                   
> print(iteratore())                                                                                                                                                                                                 
nil                            
{% endhighlight %}


oppure, semplificando:

{% highlight lua %}
lista={10,20,30,40}
for item in reverse_iter(lista) do
  print(item)
end
{% endhighlight %}


la semplicità del costrutto for ci nasconde parecchie operazioni: invocare la factory, tenerci un riferimento all'iteratore, chiamarlo ad ogni ciclo e fermare il loop quando otteniamo un valore nil.
La flessibilità di Lua ci consente di scrivere lo stesso ciclo in modo alternativo: anziché passare l'array alla funzione, passiamo la funzione come parametro:

{% highlight lua %}
lista={5,6,7,8,9}
function alrovescio(f)
  for i=5,1,-1 do f(lista[i]) end
end
{% endhighlight %}

e quindi stampare tutti gli elementi con:

{% highlight lua %}
alrovescio(print)
{% endhighlight %}

ma anche fare qualcos'altro, per esempio filtrare i valori pari:

{% highlight lua %}
alrovescio(function(x)
  if (x%2)>0 then print(x) end
end)  
{% endhighlight %}

l'uso di questo stile di programmazione è tipico dei linguaggi funzionali, ma come abbiamo visto è semplice utilizzare lo stesso paradigma in Lua. Qualcuno si è perfino divertito a creare un interprete Lisp : http://urn-lang.com/


