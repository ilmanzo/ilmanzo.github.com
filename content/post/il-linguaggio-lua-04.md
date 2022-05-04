---
layout: post
title: "il linguaggio Lua: parte 4"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2017-04-11
---


segue dalla [terza parte](https://ilmanzo.github.io/post/il-linguaggio-lua-03/)

# “Moonlight Bay” (ovvero: “chiedi chi erano i vectors”)


L'unica struttura dati disponibile in Lua è rappresentata dagli array o meglio, dalle tabelle (o hash): array associativi formati da coppie chiave-valore, nelle quali sia la chiave sia il valore possono essere qualsiasi tipo di dato. Vediamo un paio di esempi, dapprima un normale vettore:

{{< highlight lua >}}
> i = 3
> a = {1,3,5,7,9}
> print(i,a[3],a[4],a[i+3])
{{</ highlight >}}

questa sequenza stampa i valori 3,5,7,nil; la prima cosa che appare diversa rispetto ad un altro linguaggio è che gli indici per gli array partono da 1 anziché da zero; la seconda è che un eventuale sforamento dell'array non causa errore ma semplicemente ritorna nil.
Le tabelle Lua sono flessibili... Esploriamole con un esempio di complessità crescente.

{{< highlight lua >}}
>band={ Paul='basso', Ringo='batteria', George='chitarra', John='chitarra'}
>print(band['Ringo'])
batteria
{{</ highlight >}}

ma anche, con una sintassi semplificata:

{{< highlight lua >}}
>print(band.Ringo)
batteria
{{</ highlight >}}

E ovviamente funziona anche in modifica:

{{< highlight lua >}}
>band.Paul='chitarra'
{{</ highlight >}}

È semplice aggiungere nuovi elementi (anche se gli effetti non sono sempre positivi!):

{{< highlight lua >}}
>band.Yoko='sitar'
{{</ highlight >}}

se volessimo vedere il contenuto di tutta la tabella, non basterebbe un semplice print band, ma occorrerà iterare sui singoli elementi:

{{< highlight lua >}}
>for k,v in pairs(band) do print(k,v) end
{{</ highlight >}}

I fans saranno felici di sapere che basta impostare un elemento a nil per rimuoverlo dalla tabella:

{{< highlight lua >}}
>band.Yoko=nil
{{</ highlight >}}

Come dicevamo, un hash può contenere qualsiasi tipo di dato, comprese altre tabelle:

{{< highlight lua >}}
>band.tour={“Londra”,”Parigi”,”Madrid”,”Roma”}
>for city in 1,4 do print(band.tour[city]) end
{{</ highlight >}}

e via complicando:

{{< highlight lua >}}
>band.playlist={
>>{titolo=“Love me do”,voto=8.5},
>>{titolo=”Let it be”, voto=8},
>>yday={titolo=”Yesterday”,voto=7.5},
>>help={titolo=”Help”,voto=7.5} 
>>}
{{</ highlight >}}


possiamo accedere ai singoli elementi delle sotto-tabelle con la sintassi

{{< highlight lua >}}
>print(band['tour'][1])
{{</ highlight >}}

o più semplicemente

{{< highlight lua >}}
>print(band.tour[1])
{{</ highlight >}}

e in maniera analoga, avendo assegnato delle reference agli elementi, richiamarli per nome:

{{< highlight lua >}}
>print(band.playlist.help.voto)
{{</ highlight >}}

Anticipo che quando gli elementi di una tabella sono funzioni, otteniamo un comportamento object-oriented:

{{< highlight lua >}}
>function suona(song)
>>print(“Stiamo suonando”,song)
>>end
>band.playfunc=suona
{{</ highlight >}}


