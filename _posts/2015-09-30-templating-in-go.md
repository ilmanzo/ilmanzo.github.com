---
layout: post
title: "sample template usage in the Go Programming Language"
description: "how to use the standard library template of the Go Programming Language"
category: programming
tags: [golang, template,programming,example]
---
{% include JB/setup %}


[The GO programming language](https://golang.org/) has a nice and useful standard library, which includes a powerful templating engine out of the box.

Here I wrote an example, generating HTML output from a simple data structure.

{% highlight Go linenos %}
    package main

    import (
            "html/template"
            "log"
            "os"
    )

    func main() {
    
         page := `
         <!DOCTYPE html>
         <html><head><title>my todo list</title></head>
         <body><h1>my TODO list</h1>
         <ul>
         {{ range $item := . }}
         <li> {{ $item.Priority }} {{ $item.Topic }} </li>
         {{ end }}
         </ul>
         </body></html>
         `

            type Todo struct {
                    Priority int
                    Topic    string
            }

            var todos = []Todo{
                    {1, "Take out the dog"},
                    {2, "Feed the cat"},
                    {3, "Learn GO programming"},
            }

            t := template.Must(template.New("page").Parse(page))
    
            err := t.Execute(os.Stdout, todos)
            if err != nil {
                    log.Println("executing template:", err)
            }
    }
{% endhighlight %}


This program generates the following HTML output:

{% highlight html %}
     <!DOCTYPE html>
     <html><head><title>my todo list</title></head>
     <body><h1>my TODO list</h1>
     <ul>

     <li> 1 Take out the dog </li>

     <li> 2 Feed the cat </li>

     <li> 3 Learn GO programming </li>

     </ul>
     </body></html>
{% endhighlight %}

Next step: use the template to provide interactive web pages ...



