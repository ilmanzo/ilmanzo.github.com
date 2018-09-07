---
layout: post
title: "il linguaggio Lua: parte 11"
description: "introduzione al linguaggio Lua"
category: programming
tags: [lua, programming, tutorial, linux, italian]
---
{% include JB/setup %}

segue dalla [parte 11](http://ilmanzo.github.io/programming/2018/09/04/il-linguaggio-lua-11)

# segnalazioni lunari

Tra le *rocks* più interessanti citiamo quelle che permettono le operazioni di networking, come **luasocket**; salendo di livello, spicca il **Kepler project**, che comprende un intero stack per applicazioni web: **Lapis micro framework**, il framework MVC **Sailor**, e **TurboLua**, un tool per costuire velocissimi microservizi REST .

Concludiamo la panoramica sulle librerie accennando ai moduli per creare interfacce grafiche; al pari degli altri linguaggi di scripting, Lua offre binding per i maggiori toolkit grafici: curses, GTK, QT, fltk, wx si usano come negli altri linguaggi e sarebbe qui tedioso illustrarne le modalità. Ci focalizzeremo invece su due progetti peculiari, rispettivamente Lua Visual Controls (VCLua) e LÖVE , che hanno l'ulteriore pregio di essere leggeri e snelli.
Scarichiamo e installiamo VCLua:

$ wget http://luaforge.net/frs/download.php/4705/vclua-0.3.5-linux-gtk2.zip

scompattiamo e copiamo la shared library nella directory corrente:

$ unzip vclua*.zip && cp vclua*/bin/vcl.so .

Di seguito una piccola dimostrazione dell’uso di questa libreria.

{% highlight lua %}
-- guibutton.lua
require "vcl"

mainForm = VCL.Form("mainForm")

mainForm.Caption = "VCLua application"
mainForm.onclosequery = "onCloseHandler" 

function onCloseHandler(Sender)
	return true -- the form can be closed
end

button = VCL.Button(mainForm)
button.onclick = "onButtonClick"
button.Caption="Close"

function onButtonClick(sender)
  print "bottone premuto"
  mainForm:Close()
end

mainForm:ShowModal()
mainForm:Free()
{% endhighlight %}

LÖVE, che ha come motto “Don’t forget to have fun” non è solo una libreria grafica, ma un completo framework: il programmatore ha il compito di scrivere poche funzioni che vengono richiamate periodicamente dall’ambiente runtime. Vediamo il meccanismo con un esempio pratico. Anzitutto scarichiamo e installiamo il software con un 

$ sudo apt-get install love

oppure visitando il sito http://love2d.org/ ; verifichiamo il funzionamento con un 

$ love --version 

ora creiamo una nuova directory

$ mkdir hello ; cd hello

e dentro questa prepariamo un file di nome main.lua con il seguente contenuto:

{% highlight lua %}
function love.load()
  love.graphics.setFont(love.graphics.newFont(70))
  love.graphics.setBackgroundColor(255,255,150)
  love.graphics.setColor(0,0,160)
end

function love.draw()
  love.graphics.print("Hello World", 200, 300)
end
{% endhighlight %}

abbiamo finito; possiamo vedere il risultato lanciando

$ love hello

o, per i pigri, in figura [love_hello.png]
LÖVE si basa sul concetto di callback: il framework cerca determinate funzioni dentro il nostro script e le esegue su necessità; ad esempio love.load() viene invocata alla partenza, e verosimilmente conterrà il codice per caricare le immagini, i suoni e come abbiamo fatto noi impostare i colori. Altre funzioni come love.update() e love.draw() vengono eseguite ripetutamente (anche più volte al secondo) e si occuperanno rispettivamente di aggiornare lo stato degli oggetti e di disegnarli a video. Essendo un ambiente pensato per sviluppare videogiochi, abbiamo a disposizione una vasta serie di routine anche per il suono, lo scrolling, la lettura dell'input (tastiera, mouse, joystick) e nelle ultime versioni anche love.physics, un potente motore fisico basato sul celebre engine Box2D (utilizzato da moltissimi giochi tra cui Angry Birds)  per simulare in maniera realistica il movimento e l'interazione tra corpi rigidi. Non essendo possibile soffermarci troppo su questi aspetti, invito gli interessati a visitare il sito di riferimento già citato.

Prima di concludere segnalo il wiki ufficiale della comunità Lua: http://lua-users.org/wiki
Una curiosità su questo sito: i costi di gestione e mantenimento sono sostenuti grazie ad una lotteria che si tiene periodicamente tra tutti gli aderenti : http://lua-users.org/wiki/LuaUsersLottery . Parteciparvi può essere un modo semplice ed efficace per sostenere un validissimo progetto opensource.