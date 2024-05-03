---
layout: post
title: "A different approach to terminal user interfaces"
description: "First steps with Bubble Tea, a Go TUI framework"
categories: linux
tags: [linux, go, golang, programming, shell, terminal]
author: Andrea Manzini
date: 2024-05-03
---

## Intro

[Bubbletea](https://github.com/charmbracelet/bubbletea) is a framework with a philosophy based on [The Elm Architecture](https://guide.elm-lang.org/architecture/):
It always breaks into three parts:

- *Model*: the state of your application
- *View*: a way to turn your state into something to display
- *Update*: a way to update your state based on messages

The framework's runtime manages everything else: messages orchestration and low-level rendering details.

## Example

Let's say you want to create the classic to-do list:
- your model will be a list of tasks, with a flag to mark them "Done"
{{< highlight Go >}}
type model struct {
    tasks  []string // items on the to-do list
    done   []bool   // which to-do items are done
}
{{</ highlight >}}

- your view will be a function that takes the model and return a string representation of the task list
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

- your update will be a function that takes a message and reacts to it, for example a keypress. Check the [docs](https://pkg.go.dev/github.com/charmbracelet/bubbletea) for details. 
{{< highlight Go >}}
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
		// here you need to process events from the framework
		// and return an updated model plus optionally a new Command to execute
	}
}
{{</ highlight >}}


- As a final step, you only need to pass the model to the framework:
{{< highlight Go >}}
func main() {
    p := tea.NewProgram(model{})
    if _, err := p.Run(); err != nil {
        fmt.Printf("There's been an error: %v", err)
        os.Exit(1)
    }
}
{{</ highlight >}}


## Something fun

Instead of the boring to-do list, as another example I implemented the classic *"bouncing ball"* with the walls that can be resizeable; you can see the program reacts to the window resize and acts accordingly.

![bouncing ball](/img/btea_bouncing_ball.gif)

 [Full size video here](/img/btea_bouncing_ball.mp4)

The source code is rather simple:

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

The only big difference here is a custom message type, used to send periodic events to the application in order to update itself without user interaction. Sounds like one can also write some games :wink: !

Of course you can find lots of examples [in the library's repository](https://github.com/charmbracelet/bubbletea/tree/master/examples).

## Wrapping up

With [Bubbletea](https://github.com/charmbracelet/bubbletea) I can also recommend some ideal "companion" libraries, all from [https://github.com/charmbracelet/](https://github.com/charmbracelet):
- [Bubbles](https://github.com/charmbracelet/bubbles) for ready made "components"
- [Lipgloss](https://github.com/charmbracelet/lipgloss) for colorization, layout and styling, more or less "CSS for the terminal"

Have fun!





