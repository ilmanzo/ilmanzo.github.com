---
layout: post
title: "il linguaggio Lua: sesta parte"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2017-12-22
---


segue dalla [quinta parte](https://ilmanzo.github.io/post/il-linguaggio-lua-05/)

# Quando il saggio indica la luna, lo sciocco guarda il dito

Nello scorse puntate abbiamo appreso le basi di un linguaggio minimalista, il cui motto è “doing more with less”, che occupa meno byte della vostra foto su Facebook e che i benchmark dichiarano il più veloce tra i linguaggi di scripting. Nato da menti brasiliane, l'hanno chiamato Lua, che vuol dire Luna in portoghese. Lua viene usato come linguaggio di scripting in Angry Birds, World of Warcraft e decine di altri videogame e software: nello scorso post abbiamo visto come creare un semplice plugin per VLC. In questo invece approfondiremo le peculiarità del linguaggio e cominceremo a guardare oltre, presentando l’ecosistema di librerie; infine nel prossimo sperimenteremo l’integrazione tra Lua e C.

# Luna di miele: zucchero sintattico

Abbiamo già studiato due elementi chiave del linguaggio Lua: le funzioni e le tabelle. L'uso di questi costrutti è talmente comune che gli autori ci mettono a disposizione alcune scorciatoie. Ad esempio scrivere

{{< highlight lua >}}
libro.pagine=268
{{</ highlight >}}

equivale a

{{< highlight lua >}}
libro[“pagine”]=268
{{</ highlight >}}

attenzione: non è invece la stessa cosa scrivere **libro[pagine]**, perché quest'ultima espressione usa l'eventuale variabile "pagine" come chiave nell'array associativo. Se pagine non è una variabile definita, in questo caso sarebbe come scrivere libro[nil]=268 il che causerebbe un errore.
Capita spesso di chiamare una funzione passando un solo argomento: se tale argomento è una costante di tipo stringa o tabella, possiamo omettere le parentesi tonde; quindi func(“ciao”) diventa func “ciao” e, analogamente, potremo tradurre

{{< highlight lua >}}
func([[ci vediamo presto]])
{{</ highlight >}}

con

{{< highlight lua >}}
func[[ci vediamo presto]]
{{</ highlight >}}

inoltre funz({x=3,y=4}) si può scrivere con un più succinto funz{x=3,y=4}. In questo ultimo caso di fatto otteniamo quello che in altri linguaggi si chiama 'named parameters', ovvero il passaggio di argomenti per nome (e non per posizione) e con lo stesso meccanismo possiamo predisporre dei valori di default ai parametri.  Vediamo un gustoso esempio:

{{< highlight lua >}}
function cena(dettagli)
  --valorizza parametri con valori di default
  primo=dettagli.primo or "pasta"
  secondo=dettagli.secondo or "pesce"
  quando=dettagli.quando or "stasera"
  print(quando.." preparo "..primo.." e "..secondo)
end

cena{secondo="carne"}
cena{primo="risotto",quando="domani"}
{{</ highlight >}}

l’output sarà:

{{< highlight lua >}}
stasera mangio pasta e carne
domani mangio risotto e pesce
{{</ highlight >}}

in pratica passiamo alla funzione una sola hashtable che contiene tutti i parametri necessari; se uno di questi non viene valorizzato, vale NIL e perciò possiamo inizializzarlo con un valore di default.

Una funzione che accetti un numero variabile di argomenti si dichiara con la sintassi a “punti di sospensione”

{{< highlight lua >}}
function chain(...)
  local result=””
  for i,v in ipairs(arg) do
    result=result..tostring(v)
  end
  return result
end
{{</ highlight >}}

questa funzione restituisce una stringa accodando tutti i parametri. Come possiamo vedere, gli argomenti vengono passati tramite l'array convenzionale arg. Notiamo anche l'uso dell'iteratore ipairs(), aspetto che approfondiremo in seguito.

{{< highlight lua >}}
print(chain(3,”\064”,-5))
3@-5
{{</ highlight >}}

per i più esperti, facciamo presente che le stringhe Lua sono immutabili, perciò per concatenare stringhe piuttosto grandi, il metodo usato in chain() è inefficiente, in quanto provoca continue allocazioni/deallocazioni. Più avanti ne scriveremo una versione ottimizzata.