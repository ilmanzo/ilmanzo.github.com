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
const templatefile = "page.gtpl"
const htmlheader = "text/html; charset=utf-8"

func CGIHandler(rw http.ResponseWriter, req *http.Request) {

	type ViewData struct {
		Todos        []string
		DisplayTodos bool
	}

	viewdata := ViewData{}

	if req.ParseForm() != nil {
		log.Println("parsing form")
	}

	// load data from file to array string
	content, err := ioutil.ReadFile(datafile)
	if err != nil {
		log.Fatal("reading data file:", err)
	}
	viewdata.Todos = strings.Split(string(content), "\n")
	viewdata.DisplayTodos = (len(viewdata.Todos) > 0)

	if len(req.Form["entry"]) > 0 {
		// request coming from submit: append to the stored list
		viewdata.Todos = append(viewdata.Todos, req.Form["entry"][0])
		data := strings.Join(viewdata.Todos, "\n")
        // save current array string to disk. TODO: locking!!
		err := ioutil.WriteFile(datafile, []byte(data), 0644)
		if err != nil {
			log.Println("writing file:", err)
		}
	}
	header := rw.Header()
	header.Set("Content-Type", htmlheader)
	t, err := template.ParseFiles(templatefile)
	if err != nil {
		log.Println("parsing template:", err)
	}
	err = t.Execute(rw, viewdata)
	if err != nil {
		log.Println("executing template:", err)
	}

}

func main() {
	err := cgi.Serve(http.HandlerFunc(CGIHandler))
	if err != nil {
		fmt.Println(err)
	}
}
