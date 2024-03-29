---
layout: post
title: "semplice rate limit in Sinatra"
description: ""
categories: programming
tags: [sinatra, ruby, ratelimit]
author: Andrea Manzini
date: 2012-12-21
---

Giocando con [Sinatra](http://www.sinatrarb.com/) ho avuto l'esigenza di servire una determinata pagina solo con un certa frequenza (tecnicamente un **rate-limit**); la cosa si puo' fare installando il *middleware* [Rack:Throttle](https://github.com/datagraph/rack-throttle) ma non volevo aggiungere un'altra gemma alle dipendenze...

In questo esempio se al server arriva piu' di una richiesta in un intervallo di cinque secondi, rispondiamo a tono...

{{< highlight ruby >}}

SECONDS_BETWEEN_REQUEST=5
 
enable :sessions
 
def ratelimit?
  now=Time.new.to_i
  session['lastrequest']||=0 #inizializza se non presente
  result=(now-session['lastrequest'])<SECONDS_BETWEEN_REQUEST #passati dall'ultima richiesta ?
  session['lastrequest']=now # aggiorna
  return result
end
 
get '/' do
  if ratelimit?
    return "<h1>sorry, rate limit exceeded!</h1>"
  end
  "<h1>hello!</h1>"
end

{{</ highlight >}}
