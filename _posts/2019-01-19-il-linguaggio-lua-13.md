---
layout: post
title: "il linguaggio Lua: parte 13"
description: "introduzione al linguaggio Lua"
category: programming
tags: [lua, programming, tutorial, linux, italian]
---
{% include JB/setup %}

segue dalla [parte 12](http://ilmanzo.github.io/programming/2018/10/24/il-linguaggio-lua-12)

# Upvalue e Closure

Per chi non ha familiarità con i concetti di programmazione funzionale questi termini possono sembrare un po’ oscuri; vediamo di chiarirli con un semplice esempio:

{% highlight lua %}
-- definisco una funzione che parte da un numero N e conta alla rovescia
function CreaContatore(N)

  local v=N

  local function conta(x)
     if v>=x then v=v-x end
     return v
  end

  return conta
end

-- creo qualche istanza:

contaDaDieci=CreaContatore(10)
contaDaCento=CreaContatore(100)

print(contaDaDieci(1)) 
9
print(contaDaCento(1))
99
print(contaDaCento(1))
98
print(contaDaDieci(1)) 
8
print(contaDaDieci(2)) 
6
print(contaDaCento(10))
88
{% endhighlight %}

osserviamo le variabili N,v che usate dalla funzione interna: non sono locali, ma nemmeno globali... Sono **upvalue**, ovvero riferimenti che provengono da uno stackframe esterno. Quando una funzione usa variabili definite in uno scope lessicale a livello superiore, Lua provvede a memorizzare lo stato, tecnicamente spostando la gestione degli upvalue dallo stack in una zona di memoria dedicata, perché altrimenti al ritorno della funzione lo stack verrebbe perso. Ogni funzione che usa uno o più upvalue è chiamata **closure**. Si tratta di una caratteristica molto potente perché ci permette ad esempio di implementare callback e sandbox. Un esempio a puro scopo didattico:

{% highlight lua %}
do
  local oldExecute=os.execute  -- salva vecchia funzione
  local function newExec(command)
    local a,b=command:find("rm")
    if a then 
      print("NON eseguo: "..command)
    else
      print("eseguo: "..command)
      return oldExecute(command)
    end
  end
  os.execute=newExec
end

os.execute("/bin/ls")
os.execute("/bin/rm prova.txt")
{% endhighlight %}

dopo questa ridefinizione, abbiamo creato una versione ‘sicura’ di os.execute: decidiamo noi quali comandi può lanciare l’utente... Nell’esempio, scartiamo qualsiasi cosa contenga “rm”. Proviamo:

{% highlight bash %}
$ lua sandbox.lua
eseguo: /bin/ls
coroutine.lua  sandbox.lua  
NON eseguo: /bin/rm prova.txt
{% endhighlight %}

