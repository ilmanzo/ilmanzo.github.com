---
layout: post
title: "semplice rate limit in Sinatra"
description: ""
category: 
tags: [sinatra, ruby, ratelimit]
---
{% include JB/setup %}

Giocando con Sinatra ho avuto l'esigenza di servire una determinata pagina solo con un certa frequenza (tecnicamente un **rate-limit**); la cosa si può fare installando il *middleware* Rack:Throttle ma non volevo aggiungere un'altra gemma alle dipendenze...

<script src="https://gist.github.com/4353368.js"></script>

