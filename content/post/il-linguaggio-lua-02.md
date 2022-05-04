---
layout: post
title: "il linguaggio Lua: parte 2"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2016-05-24
---


segue dalla [prima parte](http://ilmanzo.github.io/programming/2016/04/13/il-linguaggio-lua-01)

# Moonwalking: Tipi di dato

Nello scorsa puntata abbiamo utilizzato due degli otto tipi disponibili: i numeri e le stringhe. Per semplicita', Lua non distingue tra interi e floating point: tutti i valori numerici sono conservati come double, cioe' in virgola mobile a doppia precisione. Nel caso la CPU non disponesse di unita' FPU, è possibile cambiare una riga nel sorgente (per l'esattezza, #define LUA_NUMBER in lua.h) e ricompilare; questo si fa tipicamente nei sistemi embedded con processori a basse prestazioni. Le stringhe posso essere delimitate da apici singoli o doppi, nel qual caso vengono espanse le usuali sequenze di escape come \b e \n; usando invece i delimitatori [[ ]], possiamo scrivere stringhe su piu' righe e disattivare l'interpolazione. Vediamo un paio di esempi, sfruttando l'opzione -e per eseguire codice da riga di comando:

{{< highlight bash >}}
$ lua -e 'print("questo va\n a capo")'
questo va
 a capo
$ lua -e 'print([[questo \n invece no]])'
questo \n invece no
{{</ highlight >}}

La funzione built-in print è piuttosto povera nella formattazione, se volessimo qualcosa di più complesso dovremmo ricorrere alla libreria string.format, ma andiamo con ordine. Attenzione: Lua converte stringhe numeriche in numeri dove ciò abbia senso, quindi è lecito fare

{{< highlight bash >}}
$ lua
>a=”3”+1
>b=2+2
>print(a,b,a==b)
4 4 true
{{</ highlight >}}

Mentre una riga come

{{< highlight bash >}}
>a=”3”+”x”
{{</ highlight >}}

causa un errore di sintassi: per concatenare due stringhe usiamo l'operatore doppio punto:

{{< highlight bash >}}
> print(“ciao”..”mondo”).
{{</ highlight >}}

(da ora in avanti omettero' l'invocazione dell'interprete e indicherò con il prompt > dove scrivere le istruzioni Lua).
Proseguiamo con l'analisi del tipo di dato boolean, che può assumere esclusivamente i valori true e false e a cui sono associati gli operatori logici and, or, not e che, come possiamo immaginare, viene usato specialmente nelle istruzioni condizionali:

{{< highlight lua >}}
if <expr> then <blocco> end
if <expr> then <blocco1> else <blocco2> end
{{</ highlight >}}

dove \<expr\> indica una qualsiasi espressione che restituisca un risultato booleano, mentre \<blocco\> sono le istruzioni che vengono o meno eseguite.
Già che parliamo di costrutti di controllo, citiamo anche i classici loop:

{{< highlight lua >}}
while <expr> do <blocco> end
repeat <blocco> until <expr>
{{</ highlight >}}

rispettivamente, ripetono il \<blocco\> finché la condizione \<expr\> è vera (nel while..do) o falsa (repeat..until). Per terminare anzitempo un ciclo si può usare nel blocco l'istruzione break:

{{< highlight lua >}}
n=43
repeat
  if n%2==0 then n=n/2
  else n=n*3+1 end
  print(n)
until n==1
{{</ highlight >}}

Un altro tipo che si usa spesso nelle condizioni è nil: esso rappresenta l'assenza di un valore (ad esempio una variabile non ancora inizializzata). Attenzione perché nil è considerato false, ma qualsiasi valore non nil è true , compresi quindi il numero zero, le stringhe vuote e gli array senza elementi:

{{< highlight lua >}}
-- questo è un commento
-- inizia lo script3.lua

if not v then
  print "variabile 'v' non dichiarata"
end

--[[
    questo è un commento su più righe
    il prossimo test non funziona come
    ci aspettiamo
--]]

s=''  -- stringa vuota

print "primo test"
if not s then   -- questa condizione non si verifica
  print "stringa vuota"
end

print "secondo test"
if #s==0 then
  print "stringa vuota"
end

if s~='' then
  print "stringa non vuota"
end
{{</ highlight >}}

questo pezzo di codice, oltre a mostrare lo stile per i commenti, non funziona come ci aspettiamo: all'inizio v vale nil, perciò otteniamo il primo output, mentre il test sulla variabile s non fa scattare la condizione: per controllare la lunghezza di una stringa o di un array in Lua c'è l'apposito operatore #. Nell'esempio notiamo anche la particolare sintassi per esprimere la condizione “diverso da”.

