---
layout: post
title: "semplice rate limit in Sinatra"
description: ""
category: 
tags: [sinatra, ruby, ratelimit]
---
{% include JB/setup %}

Giocando con [Sinatra](http://www.sinatrarb.com/) ho avuto l'esigenza di servire una determinata pagina solo con un certa frequenza (tecnicamente un **rate-limit**); la cosa si può fare installando il *middleware* [Rack:Throttle](https://github.com/datagraph/rack-throttle) ma non volevo aggiungere un'altra gemma alle dipendenze...

In questo esempio se al server arriva più di una richiesta in un intervallo di cinque secondi, rispondiamo a tono...

<script src="https://gist.github.com/4353368.js"></script>

