---
layout: post
title: "il linguaggio Lua: quinta parte"
description: "introduzione al linguaggio Lua"
categories: programming
tags: [lua, programming, tutorial, linux, italian]
author: Andrea Manzini
date: 2017-10-16
---


segue dalla [quarta parte](https://ilmanzo.github.io/post/il-linguaggio-lua-04/)

# “Sonata al chiaro di luna” : un plugin per vlc

Come dicevamo all'inizio, Lua è usato da numerose applicazioni come linguaggio di estensione; per scopi didattici ho scelto di scrivere un semplice plugin per un programma diffuso, il media player universale VLC. Con questo plugin risolveremo per sempre l'annoso problema di decidere cosa sarebbe meglio sgranocchiare durante la visione!
L'integrazione con lo scripting Lua è [documentata](https://www.videolan.org/developers/vlc/share/lua/README.txt) in una serie di file `README.TXT` sparsi nella directory `$SRC/share/lua/` (dove `$SRC` è la directory dove abbiamo decompresso l'archivio del sorgente di vlc). Grazie ad essi apprendiamo che VLC supporta diversi tipi di "agganci" (hooks) con Lua: per la generazione di playlist (ad esempio trasformare una playlist Youtube in una VLC), per le interfacce di controllo (a titolo di esempio, si può comandare VLC via telnet), per il recupero di meta-informazioni sullo stream (tipicamente scaricare e visualizzare la copertina dell'album o la locandina del film in riproduzione) e, finalmente, quella che useremo noi, cioè una generica funzionalità aggiuntiva attivabile e disattivabile da menù. 
Il file README specifica che questo tipo di estensione deve contenere due funzioni Lua di nome activate() e deactivate() che verranno chiamte in concomitanza con questi due eventi. Lo script deve avere anche una funzione descriptor() che VLC chiamerà allo startup ed avrà il compito di esporre una tabella con delle informazioni sul plugin come titolo, autore, versione. Ultimo vincolo, lo script deve risiedere in uno specifico path, ovvero $LIB/vlc/lua, dove $LIB è il percorso di libvlc (il “motore” del programma) a livello di sistema oppure $HOME/.local/share/vlc/lua, soluzione che permette ad ogni utente di usare i propri plugin; io ho pertanto copiato lo script seguente `[vlc_cibo.lua]` in `~/.local/share/vlc/lua/extensions/cibo.lua`

{{< highlight lua >}}

-- da salvare in $HOME/.local/share/vlc/lua/extensions

-- ritorna una tabella con una serie di dati sul plugin
-- ad esempio il titolo da mostrare nel menu
function descriptor()
    return { 
      version = "0.1";
      capabilities = {};
      title="cibarie giuste"; 
    }
end

-- funzione chiamata quando l'utente seleziona il plugin dal menu
function activate()
    local durata=vlc.input.item():duration()
    durata=math.floor(durata/60)
    local msg="per soli "..tostring(durata).." minuti ci accontentiamo del popcorn"
    if durata>60 then
      msg="il film sembra lungo, meglio ordinare una <b>pizza</b>"
    end
    dlg=vlc.dialog("cibarie giuste")
    dlg:add_label(msg)
    dlg:add_button("Chiudi",clicked) -- associa al click del pulsante la funzione clicked
    vlc.playlist.pause() -- ferma la riproduzione
end

-- chiamata quando l'utente clicca sul pulsante Chiudi della message box
function clicked()
    vlc.deactivate()
end

-- chiamata da VLC quando l'utente disattiva il plugin
function deactivate()
    vlc.playlist.play() -- fa ripartire il filmato
end

function close()
    vlc.deactivate()
end


{{</ highlight >}}


Analizziamo rapidamente il sorgente; dopo i commenti iniziali troviamo la funzione descriptor, che nel nostro caso inizializza e ritorna al chiamante una tabella con un solo campo, cioè il titolo del plugin; è l'unico indispensabile e come si vede in figura è ciò che troveremo come voce di menu in VLC. 

![figura7_lua_vlc](/img/lua_fig007_vlc_luaplugin_menu.png "vlc menu with added plugin")

La seconda funzione è cruciale: viene chiamata quando l'utente seleziona il plugin. Come prima cosa si fa dare la durata in secondi dell'attuale media in riproduzione. VLC infatti espone verso Lua un “oggetto” vlc (vedremo nel prossimo articolo come implementare questa tecnica) tramite il quale ciascun plugin può interagire col media player. Grazie alla documentazione apprendiamo che la funzione input.item() dell'oggetto vlc ritorna un riferimento al film che stiamo guardando. A sua volta questo oggetto ha una serie di metodi, tra i quali duration() che fornisce la lunghezza in secondi. In questo esempio la durata viene convertita in minuti (divisione per 60) ed utilizzata come parametro per stabilire quale messaggio visualizzare.
Usando ancora l'oggetto vlc, chiediamo al programma di creare per noi una dialog box nella quale inseriamo la nostra scritta ed un pulsante, il cui evento click viene associato ad una nostra funzione. Come ultima operazione, decidiamo di attirare l'attenzione chiedendo al media player di mettere in pausa la riproduzione, così l'utente potrà leggere l'avviso e prepararsi le giuste cibarie! 

![figura8_lua_vlc](/img/lua_fig008_vlc_luaplugin_attivo.png "vlc with plugin active")

La terza funzione dello script è quella che viene chiamata da VLC quando l'utente ha cliccato sul pulsante della dialog box; in questo esempio abbiamo scelto di disattivare il plugin (provocando quindi l'esecuzione della prossima funzione), ma nessuno ci vieta di scrivere del codice per ordinare effettivamente la pizza tramite un web service...
Ci resta solo la deactivate(): qui andrebbero eseguite tutte le operazioni di pulizia del plugin, nel nostro caso ci limitiamo a far ripartire il filmato.

A parte la dubbia utilità di questo plugin didattico, possiamo notare alcune cose interessanti: anzitutto la robustezza, nel senso che qualunque errore o problema in uno script Lua non metterà minimamente in crisi il programma principale; apprezziamo inoltre la chiarezza e la semplicità di avere interfacce ben definite, nel senso che il team VLC ha deciso per noi cosa esporre del programma e come farlo, nascondendoci la complessità dell'implementazione, ma allo stesso tempo consentendoci di aggiungere nostre funzionalità. Infine non trascuriamo la portabilità, ovvero che questo plugin funzionerà allo stesso modo e senza modifiche anche in ambiente Windows o Mac.


