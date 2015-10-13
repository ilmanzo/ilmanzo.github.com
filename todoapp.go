package main

import (
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
	// a struct to keep together all useful data in the page
	type ViewData struct {
		Todos        []string
		DisplayTodos bool
	}

	viewdata := ViewData{}
	check(req.ParseForm(), "parsing form")
	// load data from file, one TODO for each line
	content, err := ioutil.ReadFile(datafile)
	check(err, "reading data file:")
	viewdata.Todos = strings.Split(string(content), "\n")
	viewdata.DisplayTodos = (len(viewdata.Todos) > 0)

	if len(req.Form["entry"]) > 0 {
		// request is coming from submit: append to the stored list
		viewdata.Todos = append(viewdata.Todos, req.Form["entry"][0])
		data := strings.Join(viewdata.Todos, "\n")
		//and save data to file. TODO: handle locking!
		err := ioutil.WriteFile(datafile, []byte(data), 0644)
		check(err, "writing file")
	}
	// output HTML page using the template
	header := rw.Header()
	header.Set("Content-Type", htmlheader)
	t, err := template.ParseFiles(templatefile)
	check(err, "parsing template")
	err = t.Execute(rw, viewdata)
	check(err, "executing template")
}

func check(e error, msg string) {
	if e != nil {
		log.Println(msg, e)
		panic(e)
	}
}

func main() {
	err := cgi.Serve(http.HandlerFunc(CGIHandler))
	check(err, "serve CGI request")
}
