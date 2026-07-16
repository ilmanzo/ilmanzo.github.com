---
layout: post
title: "Un approccio diverso alle interfacce utente da terminale"
description: "Primi passi con Bubble Tea, un framework TUI in Go"
categories: linux
tags: [linux, go, golang, programming, shell, terminal]
author: Andrea Manzini
date: 2024-05-03
---

## Introduzione

[Bubbletea](https://github.com/charmbracelet/bubbletea) è un framework con una filosofia basata su [The Elm Architecture](https://guide.elm-lang.org/architecture/):
Per farla semplice, si divide in tre parti:

- *Model*: lo stato della tua applicazione
- *View*: un modo per trasformare il tuo stato in qualcosa da mostrare a schermo
- *Update*: un modo per aggiornare lo stato in base ai messaggi

Il runtime del framework gestisce tutto il resto: dall'orchestrazione dei messaggi ai dettagli di rendering a basso livello.

## Esempio

Ipotizziamo di voler creare la classica lista di cose da fare (to-do list):
- il modello sarà una struct contenente una lista di task e un flag per contrassegnarli come completati ("Done")
{{< highlight Go >}}
type model struct {
    tasks  []string // items on the to-do list
    done   []bool   // which to-do items are done
}
{{</ highlight >}}

- la vista sarà una funzione che accetta il modello e restituisce una rappresentazione sotto forma di stringa della lista dei task
{{< highlight Go >}}
func (m model) View() string {
    var s strings.Builder

    // Iterate over our choices
    for i, tasks := range m.tasks {

        // Is this task done?
        if m.done[i] {
			s.WriteString("[x] ")
		} else {
			s.WriteString("[ ] ")
		}
		s.WriteString(tasks[i]+"\n")
    }
    return s.String()
}
{{</ highlight >}}

- l'aggiornamento sarà una funzione che riceve un messaggio proveniente dal framework e reagisce ad esso, ad esempio la pressione di un tasto, un clic del mouse o il ridimensionamento della finestra.
Consulta la [documentazione](https://pkg.go.dev/github.com/charmbracelet/bubbletea) per i dettagli.
{{< highlight Go >}}
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
		// here you need to process events from the framework
		// and return an updated model plus optionally a new Command to execute
	}
}
{{</ highlight >}}

- Come ultimo passaggio, occorre solo passare il modello al framework:
{{< highlight Go >}}
func main() {
    p := tea.NewProgram(model{})
    if _, err := p.Run(); err != nil {
        fmt.Printf("There's been an error: %v", err)
        os.Exit(1)
    }
}
{{</ highlight >}}


## Qualcosa di divertente

Invece della noiosa to-do list, come altro esempio ho implementato la classica *"palla che rimbalza"* (bouncing ball) con pareti ridimensionabili; si può vedere come il programma reagisca al ridimensionamento della finestra agendo di conseguenza.

![bouncing ball](/img/btea_bouncing_ball.gif)

 [Video a schermo intero qui](/img/btea_bouncing_ball.mp4)

Il codice sorgente è piuttosto semplice:

{{< highlight Go "linenos=true" >}}
package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

type model struct {
	width  int
	height int
	x      int
	y      int
	dx     int
	dy     int
}

type tickMsg time.Time

func (m model) Init() tea.Cmd {
	return tickCmd()
}

// Custom message tied to a timer
func tickCmd() tea.Cmd {
	return tea.Tick(time.Millisecond*20, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.WindowSizeMsg:
		m.height = msg.Height
		m.width = msg.Width

	case tickMsg:
		x1 := m.x + m.dx
		y1 := m.y + m.dy
		if x1 < 0 || x1 > m.width {
			m.dx = -m.dx
		}
		if y1 < 0 || y1 > m.height {
			m.dy = -m.dy
		}
		m.x += m.dx
		m.y += m.dy
		return m, tickCmd()

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		}
	}
	// Return the updated model to the Bubble Tea runtime for processing.
	return m, nil
}

func (m model) View() string {
	var s strings.Builder
	for i := 0; i < m.y; i++ {
		s.WriteString("\n")
	}
	s.WriteString(strings.Repeat(" ", m.x))
	s.WriteString("o")
	return s.String()
}

func main() {
	p := tea.NewProgram(model{x: 1, y: 1, dx: 1, dy: 1}, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("There's been an error: %v", err)
		os.Exit(1)
	}
}
{{</ highlight >}}

L'unica grande differenza qui è un tipo di messaggio personalizzato, utilizzato per inviare eventi periodici all'applicazione in modo che si aggiorni da sola senza l'interazione dell'utente. Sembra proprio che si possano scrivere anche dei giochi :wink: !

Naturalmente puoi trovare moltissimi esempi [nella repository della libreria](https://github.com/charmbracelet/bubbletea/tree/master/examples).

## Conclusioni

Insieme a [Bubbletea](https://github.com/charmbracelet/bubbletea), consiglio anche alcune librerie di "supporto" ideali, tutte disponibili su [https://github.com/charmbracelet/](https://github.com/charmbracelet):
- [Bubbles](https://github.com/charmbracelet/bubbles) per componenti già pronti
- [Lipgloss](https://github.com/charmbracelet/lipgloss) per colorazione, layout e stile, più o meno un "CSS per il terminale"

Buon divertimento!
