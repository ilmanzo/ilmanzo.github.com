---
layout: post
title: "CGI with the Go Programming Language"
description: "standard library of the Go Programming Language: CGI and templates"
category: programming
tags: [golang, template,programming,example]
---
{% include JB/setup %}


{% highlight c %}
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
                Todos        []string
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


