---
layout: post
title: "il linguaggio Lua: parte 3"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2017-03-20
---


segue dalla [seconda parte](http://ilmanzo.github.io/programming/2016/05/24/il-linguaggio-lua-02)

# Che fai tu luna in ciel ? : le funzioni


Fino a che scriviamo script di poche righe, possiamo inserire le istruzioni nel programma principale, ma aumentando la complessità diventa necessario organizzare il codice in pezzi indipendenti e riutilizzabili; come in tutti gli altri linguaggi, in Lua è possibile definire funzioni; vediamo un esempio piuttosto classico:


{{< highlight lua >}}
function fattoriale(n)
  local f=1   -- variabile locale alla funzione
  for i=2,n do
    f=f*i
  end
return f
{{</ highlight >}}


Abbiamo definito la funzione fattoriale, che da ora in avanti possiamo richiamare nel nostro codice:

{{< highlight lua >}}
print(fattoriale(10))
{{</ highlight >}}


Notiamo che la variabile f ha il prefisso local: questo perché per default in Lua le variabili sono globali se non viene esplicitato diversamente. Vediamo un esempio:

{{< highlight lua >}}
pippo,pluto=1,2
function func()
  pippo=3
  local pluto=4
end
func()
print(pippo,pluto)
{{</ highlight >}}


stamperà 3,2, perché il valore di 'pippo' è stato sovrascritto dentro la funzione, in quanto ogni variabile non dichiarata esplicitamente local ha visibilità globale. Fanno eccezione gli iteratori dei cicli:

{{< highlight lua >}}
i=10
for i=1,3 do
    print(i)
end
print(i)

1
2
3
10
{{</ highlight >}}


in conclusione: nelle funzioni conviene sempre dichiarare le variabili 'local', a meno che non sappiate esattamente cosa state facendo!

Per i più virtuosi, divertiamoci a scrivere il fattoriale in maniera ricorsiva:

{{< highlight lua >}}
function fattorialeR(n)
  if n==0 then return 1
  else return n*fattorialeR(n-1)
 end
end 
{{</ highlight >}}

Questo tipo di ricorsione (tail recursion) è implementata in maniera efficiente in Lua, in quanto il compilatore provvede ad ottimizzare le chiamate in modo da non utilizzare spazio nello stack.

Una funzione è anche un tipo di dato, ovvero è possibile ottenere riferimenti a funzioni e utilizzarli associandoli a variabili. Potremmo scrivere ad esempio:

{{< highlight lua >}}
func=fattoriale
if recurse then func=fattorialeR
print(func(10))
{{</ highlight >}}

che utilizza la versione ricorsiva o iterativa a seconda di una scelta operata in precedenza. Come conseguenza, possiamo scrivere funzioni che ritornano funzioni:

{{< highlight lua >}}
function makeIncr(x)
  local i=x
  return function()
      i=i+1
      return i
  end
end

dieci=makeIncr(10)
cento=makeIncr(100)
for i=1,5 do
    print(dieci(),cento())
end
{{</ highlight >}}

Non è necessario capire immediatamente l'utilità di costrutti avanzati come questo... Basti dire che sono la base della programmazione funzionale e del concetto di coroutine in Lua. Notiamo infatti che ciascuna delle due funzioni 'mantiene' il proprio stato (in questo caso il contatore) indipendentemente, pur essendo generate dalla stessa 'madre'.

