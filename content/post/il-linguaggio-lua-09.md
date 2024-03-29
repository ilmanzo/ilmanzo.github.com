---
layout: post
title: "il linguaggio Lua: parte 9"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2018-06-22
---


segue dalla [parte 8](https://ilmanzo.github.io/post/il-linguaggio-lua-08/)

# il modulo lunare

Per mantenere la sua natura minimalista, Lua ha ben poche funzionalità incluse nel linguaggio e delega molti aspetti a librerie e moduli esterni. Ad esempio le operazioni matematiche sono accessibili nel package, o se preferite, **namespace** col prefisso *math*:

{{< highlight bash >}}
$ lua
>print(math.sin(math.pi/2))
1
{{</ highlight >}}

sarebbe oltremodo noioso elencare tutte le funzioni presenti, basti dire che oltre alle funzioni trigonometriche abbiamo logaritmi, esponenziali, modulo, minimo, massimo, arrotondamenti e generazione di valori random.
Per operare in modo agevole con tabelle e vettori abbiamo a disposizione il modulo *table*:

{{< highlight lua >}}
>t={10,30,40}
>table.insert(t,2,"venti")
>table.insert(t,"cinquanta")
>table.foreach(t,print)
1 10
2 venti
3 30
4 40
5 cinquanta


>a={8,3,6,1,7}
>table.sort(a)
>print(table.concat(a,"-"))
1-3-6-7-8
{{</ highlight >}}

e, come promesso tempo fa, ecco versione ottimizzata della funzione chain():

{{< highlight lua >}}
function chain2(...)
  local result={}
  for i,v in ipairs(arg) do
    result[i]=tostring(v)
  end
  return table.concat(result)
end
{{</ highlight >}}

poiché evita la creazione di stringhe temporanee, questa funzione risulta di gran lunga più efficiente della precedente.
Le funzioni di dialogo col sistema operativo sono invece raggruppate nel package *os*:

{{< highlight lua >}}
>print(os.getenv('HOME'))
/home/andrea
>os.execute('/bin/ls')
{{</ highlight >}}

mentre per gestire flussi di dati in ingresso e in uscita (input/output) servirà il modulo *'io'*:

{{< highlight lua >}}
fdati=io.open('dati.txt','w')
for i=1,10 do
  fdati:write("riga",i,"\n")
end
fdati:close()

for riga in io.lines("dati.txt") do
  print("lettura",riga)
end
{{</ highlight >}}



Per la manipolazione di stringhe useremo il prefisso *string*:

{{< highlight lua >}}
$lua
>a="gnu/linux"
>print(string.upper(a))
GNU/LINUX
>b=string.rep("x",2^20)  -- stringa da 1 Megabyte
>print(string.len(a..b))
1048585
>print(string.sub(a,1,3)) -- primi tre caratteri
gnu
>print(string.sub(a,-5,-1) -- ultimi cinque caratteri
linux
{{</ highlight >}}

lo stesso modulo contiene anche funzioni di formattazione, con una sintassi analoga alla printf(3) del C:

{{< highlight lua >}}
>tag,titolo,numero="h1","titolo",2
>s=string.format("<%s>%s %d</%s>",tag,titolo,numero,tag)
>print(s)
<h1>titolo 2</h1>
{{</ highlight >}}

*string* fornisce una implementazione ridotta, ma efficace, **delle regular expression**.
Nell'interprete interattivo e nei nostri script le librerie built-in come math, io, os, string sono già disponibili senza dover specificare nient'altro; come vedremo più avanti, questo non vale più quando useremo Lua come libreria 'embedded' nei programmi C, perché potremo scegliere di volta in volta le funzionalità da includere o meno, con il beneficio di snellire i nostri programmi togliendo le funzionalità che non usiamo.

