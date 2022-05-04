---
layout: post
title: "il linguaggio Lua: parte 10"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2018-08-03
---


segue dalla [parte 9](https://ilmanzo.github.io/post/il-linguaggio-lua-09/)

# stringhe e regular expression

in questa puntata apriremo una piccola digressione per analizzare le funzionalità del modulo **string**, in particolare l'uso delle regular expression.

Il modulo string ci mette a disposizione potenti funzioni di ricerca e sostituzione basate su espressioni regolari. Una completa implementazione delle regexp POSIX occuperebbe più dell'intero linguaggio, ma tutto sommato le funzionalità principali sono state mantenute, e gli autori di Lua sono riusciti a impacchettare un “motore” di *pattern matching* in meno di 500 righe di codice. Vediamone per sommi capi alcune caratteristiche:
La funzione *string.find(s,p*) cerca un pattern *p* dentro la stringa *s* e ritorna una tupla di due valori: la posizione dove inizia  la corrispondenza e quella dove finisce; in caso il pattern non sia presente, ritornerà *nil*.

{{< highlight bash >}}
>s=”hello moon”
>print(string.find(s,”bazinga”))
nil
>i,j=string.find(s,”hello”)
>print(i,j)
1 5
>print(string.sub(s,i,j))
hello
{{</ highlight >}}

o, più concisamente, utilizzando la sintassi alternativa,

{{< highlight bash >}}
>print(s:sub(i,j))
hello
{{</ highlight >}}

possiamo abbreviare la ricerca ed estrazione del testo con una sola chiamata:

{{< highlight bash >}}
>print(s:match(”hello”))
hello
{{</ highlight >}}

la funzione di *replace()* richiede ovviamente un parametro in più; restituisce la nuova stringa e il numero di sostituzioni eseguite:

{{< highlight bash >}}
>k=”all your bases are belong to us”
>s,n=string.gsub(k,”s”,”z”)
>print(s,n)
{{</ highlight >}}

il tutto diventa più interessante quando ricerchiamo o sostituiamo un pattern:

{{< highlight bash >}}
>p=”aiuole oltremisura”
>_,v=string.gsub(p,”[aeiou]”,””)
>print(“trovate”,v,”vocali”)
{{</ highlight >}}

in questo caso scartiamo il primo valore ritornato assegnandolo a una variabile fittizia (underscore) perché ci serve solo il conteggio.

{{< highlight lua >}}
>html=[[<a href=”http://www.kernel.org”> <img src=”pinguino.gif”> </a>]]
>greedy=”href=(.+)>”
>lazy=”href=(.-)>”
>print(string.match(html,greedy)) -- non proprio quello che vogliamo
"http://www.kernel.org"> img src="pinguino.gif" </a 
>print(string.match(html,lazy))
"http://www.kernel.org" 
{{</ highlight >}}

*string.match* ha anche l'equivalente **string.gmatch** che funziona come un iteratore. La sequenza di escape %b serve per il matching di testo racchiuso tra delimitatori. Quindi per tirare fuori tutti i tag da un html:

{{< highlight lua >}}
> for tag in string.gmatch(html,”%b<>”) print(tag) end
{{</ highlight >}}

vale anche per gfind, ad esempio per implementare la classica funzione split() che suddivide le parole di un testo, che non è implementata nella libreria standard:

{{< highlight lua >}}
function split(s)
  local words={}
  for w in s:gfind(”%a”) do
    table.insert(words,w)
  end
  return words
end
{{</ highlight >}}

per mostrare le potenzialità del meccanismo di ricerca e sostituzione scriviamo un convertitore di formato, che trasforma un comando in stile LaTex come \comando{testo libero} in XML <comando>testo libero</comando>:

{{< highlight lua >}}
>s=”la nostra \quote{missione} è quasi \em{compiuta}” 
>s=string.gsub(s, “\\(%a+){(.-)}”,”<%1>%2</%1>”)
>print(s)
la nostra <quote>missione</quote> è quasi <em>compiuta</em>”
{{</ highlight >}}

invece di un testo fisso o un pattern, possiamo passare a gsub una funzione, che riceve come input il testo cercato e restituisce la sostituzione. Esemplifichiamo questo concetto con una routine che decodifica gli URL encoding:

{{< highlight lua >}}
-- funzione ‘helper’ di appoggio
-- trasforma una coppia di cifre hex nel carattere corrispondente
function hextochar(n)
  return string.char(tonumber(n,16))
end

function unescape(url)
  url=string.gsub(url,'+',' ') -- trasforma + in spazi
  url=string.gsub(url,”%%(%x%x)”, hextochar )  -- applica la funzione di trasformazione hex->char
  return url
end

>q=”a%2Bb+%3D+c”
>print(unescape(q))
a+b = c
{{</ highlight >}}

prima di concludere, come 'chicca' finale segnalo un software : [Lua-Quick-Try-Out](http://www.brischalle.de/Lua-Quick-Try-Out/Lua-Quick-Try-Out_en.php) 

è un comodo ambiente di sviluppo interattivo dove scrivere ed eseguire comandi e script Lua, compresi esperimenti di grafica bitmap e vettoriale... Si scrive codice e si vede subito il risultato, in modo molto simile al basic dei primi homecomputer a 8bit!

