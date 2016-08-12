---
layout: post
title: "a simple HTTP rewriting proxy"
description: ""
category: programming
tags: [golang, programming, proxy, http, hacking]
---
{% include JB/setup %}

This is an example of using [goproxy](https://github.com/elazarl/goproxy), a fast and robust multithread proxy engine to develop an HTTP proxy that rewrites content on the fly, with multiple search and substitutions. It can be useful for debugging and other less noble (but useful) purposes ...

{% highlight go %}
// rewriting_proxy project main.go
package main

import (
	"bytes"
	"flag"
	"io/ioutil"
	"log"
	"net/http"

	"github.com/elazarl/goproxy"
)

var replacements = []struct {
	from []byte
	to   []byte
}{
	{[]byte("#e8ecec"), []byte("Red")},                       // ugly colors!!
	{[]byte("Comic Sans MS"), []byte("Lucida Sans Unicode")}, // for eyes sanity
	{[]byte("Java "), []byte("Golang ")},                     // just joking
}

func myHandler(resp *http.Response, ctx *goproxy.ProxyCtx) *http.Response {
	readBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		//TODO handle read error gracefully
		return resp
	}
	resp.Body.Close()
	for _, elem := range replacements {
		readBody = bytes.Replace(readBody, elem.from, elem.to, -1)
	}
	resp.Body = ioutil.NopCloser(bytes.NewReader(readBody))
	return resp
}

func main() {
	verbose := flag.Bool("v", true, "should every proxy request be logged to stdout")
	proxy := goproxy.NewProxyHttpServer()
	proxy.Verbose = *verbose
	proxy.OnResponse().DoFunc(myHandler)
	log.Fatal(http.ListenAndServe(":8081", proxy))
}

{% endhighlight %}
