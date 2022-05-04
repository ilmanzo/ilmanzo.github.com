---
layout: post
title: "il linguaggio Lua: parte 11"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2018-09-07
---


segue dalla [parte 10](https://ilmanzo.github.io/post/il-linguaggio-lua-10/)

# Rocce di Luna
Poter organizzare il codice in più file è molto utile per modularizzare i programmi, creando package che verranno caricati tramite l'istruzione require “nomefile”. Vediamo un esempio:

{{< highlight lua >}}
-- geompkg.lua
module("geom")

local function quadrato(x)
  return x*x
end

local function rettangolo(b,h)
  return b*h
end

function area(param)
  if param.lato then
    return quadrato(param.lato)
  end
  local area=rettangolo(param.base,param.altezza)
  if param.triangolo or param.trapezio then
    return area/2
  end
  return area
end
{{</ highlight >}}

{{< highlight lua >}}
-- usepkg.lua
require('geompkg')

print(geom.area{base=3,altezza=5})

print(geom.area{lato=3})

--errore, quadrato è local nel modulo 
--quindi non accessibile esternamente
print(geom.quadrato(5))
{{</ highlight >}}

nell'esempio vogliamo separare le funzioni di calcolo geometrico dal programma principale, così le raggruppiamo in un file *geompkg.lua*; notiamo che nello stesso file abbiamo definito anche delle funzioni locali che non saranno visibili all'esterno, come evidenziato dall'ultima riga di *usepkg.lua*.
più avanti impareremo come un modulo possa anche essere binario, cioè compilato come codice nativo. Verificheremo perciò come sia agevole usare da Lua le sterminate librerie disponibili in C.

Attorno a questo primitivo meccanismo di modularizzazione la comunità opensource ha sviluppato una completa infrastruttura di versioning, deploy e gestione dei pacchetti che somiglia a quelli già disponibili in altri linguaggi come Python, Ruby, Perl, e che prende il nome di **luarocks** [http://luarocks.org/](http://luarocks.org/). Grazie a questo progetto è semplicissimo installare e utilizzare numerosi moduli aggiuntivi per le più disparate esigenze, vediamo ora come sfruttarlo.

Anzitutto occorre installare luarocks, seguendo le istruzioni per compilare i sorgenti presenti sul sito o scaricando il pacchetto della nostra distribuzione preferita oppure. Su Debian/Ubuntu basta un:

{{< highlight bash >}}
$ sudo apt-get install luarocks
{{</ highlight >}}

terminata l'installazione, controlliamo il percorso del repository:

{{< highlight bash >}}
$ grep -3 servers /etc/luarocks/config.lua 
rocks_servers = {
   [[http://luarocks.org/repositories/rocks]]
}
{{</ highlight >}}

dopo esserci assicurati che l' URL indicato sia raggiungibile, possiamo provare qualche ricerca:

{{< highlight bash >}}
$ luarocks search twitter
$ luarocks search sql
{{</ highlight >}}

la maggior parte di questi progetti sono ospitati su [http://luaforge.net](http://luaforge.net), l'equivalente del più noto Sourceforge.
A titolo di esempio e tanto per rimanere nell'ambito “lightweight”, installiamo e proviamo il modulo per interfacciarsi a sqlite:

{{< highlight bash >}}
$ sudo luarocks install luasql-sqlite3
{{</ highlight >}}

se non avessimo già installato la libreria di sviluppo, eventualmente occorre un:

{{< highlight bash >}}
$ sudo apt-get install libsqlite3-dev.
{{</ highlight >}}

Ci prepariamo un database e una tabella di prova:

{{< highlight bash >}}
$ sqlite3 dati.db
SQLite version 3.22.0 2018-01-22 18:45:57
Enter ".help" for usage hints.

sqlite> create table rubrica(nome varchar(35), telefono varchar(15));
sqlite> insert into rubrica values('Linus Torvalds','0123456732');
sqlite> insert into rubrica values('Richard Stallman','932874936');
sqlite>.quit
{{</ highlight >}}

e lo interroghiamo da Lua:

{{< highlight bash >}}
$ lua
Lua 5.2.4  Copyright (C) 1994-2015 Lua.org, PUC-Rio
> require "luasql.sqlite3"
> db=luasql.sqlite3()
> conn=db:connect("dati.db")
> print(conn)
SQLite3 connection (0x99e05bc)
> curs=conn:execute("SELECT * FROM rubrica")
> print(curs:fetch())
Linus Torvalds	0123456732
> print(curs:fetch())
Richard Stallman	932874936
{{</ highlight >}}

