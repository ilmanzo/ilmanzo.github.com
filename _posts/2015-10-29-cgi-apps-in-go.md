---
layout: post
title: "CGI with the Go Programming Language"
description: "standard library of the Go Programming Language: CGI and templates"
category: programming
tags: [golang, CGI, template,programming,example]
---
{% include JB/setup %}


Following with the [GO standard library exploration](http://ilmanzo.github.io/programming/2015/09/30/templating-in-go), I've written a toy example for using the CGI features.
Native [GoLang](https://golang.org/) CGI web applications are very fast and can be useful for example in embedded systems, or in cheap web hosting where is not possible to run custom HTTP servers.
The solution has some weak points, starting from lock management, but is only presented as a proof of concept and not for real use cases.


{% highlight Go linenos %}
//save this as todoapp.go
package main

import (
    "fmt"
    "html/template"
    "io/ioutil"
    "log"
    "net/http"
    "net/http/cgi"
    "strings"
)

const datafile = "/tmp/todos.txt"
const templatefile = "/data/templates/page.gtpl"
const htmlheader = "text/html; charset=utf-8"

func CGIHandler(rw http.ResponseWriter, req *http.Request) {

    type ViewData struct {
        Todos []string
        DisplayTodos bool
    }

    viewdata := ViewData{}
    check(req.ParseForm(),"parsing form")

    // load data from file to array string
    content, err := ioutil.ReadFile(datafile)
    check(err,"reading data file:")
    viewdata.Todos = strings.Split(string(content), "\n")
    viewdata.DisplayTodos = (len(viewdata.Todos) > 0)
    if len(req.Form["entry"]) > 0 {
        // request coming from submit: append to the stored list
        viewdata.Todos = append(viewdata.Todos, req.Form["entry"][0])
        data := strings.Join(viewdata.Todos, "\n")
        // save current array string to disk. TODO: locking!!
        err := ioutil.WriteFile(datafile, []byte(data), 0644)
        check(err,"writing data file")
    }
    header := rw.Header()
    header.Set("Content-Type", htmlheader)
    t, err := template.ParseFiles(templatefile)
    check(err,"parsing template")
    err = t.Execute(rw, viewdata)
    check(err,"executing template")
}

func check(err error, msg string) {
    if err != nil {
        log.Fatal(msg,err)
    }
}

func main() {
    err := cgi.Serve(http.HandlerFunc(CGIHandler))
    check(err,"cannot serve request")
}

{% endhighlight %}

following, the template:  a simple form that displays the data and send back a POST request to the CGI.

{% highlight html %}

    <!DOCTYPE html>
    <html>
    <head><title>my todo list</title></head>
    <body>
    <h1>my TODO list</h1>
    {{ if .DisplayTodos }}
    <ul>
    {{ range $index,$item := .Todos }}
    <li> {{ $index }} {{ $item }} </li>
    {{ end }}
    </ul>
    {{ end }}
    <form action="/todoapp" method="post">
      <input type="text" name="entry" size="25">
      <input type="submit" name="submit" value="New TODO">
    </form>
    </body>
    </html>

{% endhighlight %}

the template should be saved in a folder reachable by the CGI app (see from the source: /data/templates/page.gtpl)






