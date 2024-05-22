---
layout: post
description: "An approach to headless testing of GUI programs"
title: "Headless Testing of PySide/PyQt GUI Applications with pytest-qt"
categories: linux
tags: [linux, python, tutorial, qt, testing, unit testing, gui, programming]
author: Andrea Manzini
date: 2024-05-22
---

## 🤓 Intro

Manual testing of GUI applications can become tedious and error-prone as features and complexity increase. Headless testing offers a solution by automating UI interactions without the need for a physical display. This approach allows for faster test execution, improved repeatability, and seamless integration with continuous integration and continuous delivery (CI/CD) pipelines. In this post, we'll explore how to leverage pytest-qt, a powerful framework for headless testing of [PySide/PyQt](https://wiki.qt.io/Qt_for_Python) applications.

As usual, all the code is available in my [github repository](https://github.com/ilmanzo/pyside-playground/tree/master/testable_app).

## 🧮 Example

As a starting point, let's suppose we have a rather dummy app, comprising only two buttons and a label.

![crappycounter0](/img/crappycounter0.png)

Yes, [Towel Day](https://en.wikipedia.org/wiki/Towel_Day) is approaching.

## 🤬 The problem

The application is quite simple, a numeric label that should be red when displaying odd numbers, green for even numbers. 
User can only increment or decrement the counter with the corresponding buttons. 

When we press `+1` button, the number correctly increases:

![crappycounter1](/img/crappycounter1.png)

An user kindly shows us the problem: when we press the `-1` button, *something weird is happening!*

![crappycounter2](/img/crappycounter2.png)

Probably for this simple issue we can just inspect the code and find the error in no time, but as we are testers, we want to add some tests to our interactive application.

## 🧑‍🔬 First test

To validate the error, we are going to use the [pytest-qt](https://pytest-qt.readthedocs.io/en/latest/) plugin for the [pytest](https://docs.pytest.org/) framework.
Creating a test to reproduce the issue not only helps us to spot the specific problem, but contributes to build a growing test suite that will also prevent future regressions.

Let's start with a simple test: application should be able to start up, and initial counter value must be 42. 
With `pytest`, it's just one function:

{{< highlight python >}}
from mainwindow import MainWindow

def test_application_start(qtbot):
    widget = MainWindow()
    qtbot.addWidget(widget)
    assert widget.number == 42
{{</ highlight >}}	

`qtbot` is a rather cool *Fixture* provided by `pytest-qt` plugin, to "run" our app we just need to add our widget to the `qtbot` object.

test run:

```
$ pytest                                          
=================== test session starts ======================
platform linux -- Python 3.11.9, pytest-8.2.1, pluggy-1.5.0
PySide6 6.7.0 -- Qt runtime 6.7.0 -- Qt compiled 6.7.0
rootdir: /home/andrea/projects/pyside-playground/testable_app
configfile: pytest.ini
plugins: qt-4.4.0
collected 1 item  

test_mainwindow.py .                                    [100%]

=================== 1 passed in 0.09s ========================
```


Success! As you can see, `pytest-qt` *Fixture* is handling for us all the gory details of instantiating a *QApplication*, running an event loop listening for signal/slots. The GUI doesn't even get rendered on the screen, making this approach feasible to run also in an automated environment like a CI.

## ✅ Second test

Let's add a second test, we tell the application to "press" the +1 button and expect both right number and label color attribute:

{{< highlight python >}}
import pytest
from pytestqt.qt_compat import qt_api
from mainwindow import MainWindow

@pytest.fixture
def widget(qtbot):
    widget = MainWindow()
    qtbot.addWidget(widget)
    return widget

def test_application_start(qtbot, widget):
    assert widget.number == 42

def test_inc_button(qtbot, widget):
    # click in the + button and make sure it updates the numeric label
    qtbot.mouseClick(widget.ui.btnInc, qt_api.QtCore.Qt.MouseButton.LeftButton)
    assert widget.ui.lbl_number.text()=="43"
    assert "background-color: red" in widget.ui.lbl_number.styleSheet()
{{</ highlight >}}

We also refactored the common part, by providing a widget `setup` fixture that manages the initial state for each test.
The second run is green as well:

```
$ pytest                                          
=================== test session starts ======================
platform linux -- Python 3.11.9, pytest-8.2.1, pluggy-1.5.0
PySide6 6.7.0 -- Qt runtime 6.7.0 -- Qt compiled 6.7.0
rootdir: /home/andrea/projects/pyside-playground/testable_app
configfile: pytest.ini
plugins: qt-4.4.0
collected 2 items    

test_mainwindow.py ..                                   [100%]

=================== 2 passed in 0.09s ========================
```

## 🐞 A failing test

We miss only the third test, that should trigger the issue:

{{< highlight python >}}
import pytest
from pytestqt.qt_compat import qt_api
from mainwindow import MainWindow

@pytest.fixture
def widget(qtbot):
    widget = MainWindow()
    qtbot.addWidget(widget)
    return widget

def test_application_start(qtbot,widget):
    assert widget.number == 42

def test_inc_button(qtbot,widget):
    # click in the + button and make sure it updates the numeric label
    qtbot.mouseClick(widget.ui.btnInc, qt_api.QtCore.Qt.MouseButton.LeftButton)
    assert widget.ui.lbl_number.text()=="43"
    assert "background-color: red" in widget.ui.lbl_number.styleSheet()

def test_dec_button(qtbot,widget):
    # click in the - button and make sure it updates the numeric label
    qtbot.mouseClick(widget.ui.btnDec, qt_api.QtCore.Qt.MouseButton.LeftButton)
    assert widget.ui.lbl_number.text()=="41"
    assert "background-color: red" in widget.ui.lbl_number.styleSheet()
{{</ highlight >}}

**AHA!**
(bear with me, for a QA engineer a failing test is pure happiness) 

```
$ pytest
=========================== test session starts ==========================
platform linux -- Python 3.11.9, pytest-8.2.1, pluggy-1.5.0
PySide6 6.7.0 -- Qt runtime 6.7.0 -- Qt compiled 6.7.0
rootdir: /home/andrea/projects/pyside-playground/testable_app
configfile: pytest.ini
plugins: qt-4.4.0
collected 3 items     

test_mainwindow.py ..F                                              [100%]

=============================== FAILURES =================================
___________________________ test_dec_button ______________________________

qtbot = <pytestqt.qtbot.QtBot object at 0x7fc7912d1210>
widget = <mainwindow.MainWindow(0x5615c0cb2ae0, name="MainWindow") at 0x7fc7912d1580>

    def test_dec_button(qtbot,widget):
        # click in the - button and make sure it updates the numeric label
        qtbot.mouseClick(widget.ui.btnDec, qt_api.QtCore.Qt.MouseButton.LeftButton)
>       assert widget.ui.lbl_number.text()=="41"
E       AssertionError: assert '-1' == '41'
E         
E         - 41
E         + -1

test_mainwindow.py:25: AssertionError
========================= short test summary info =========================
FAILED test_mainwindow.py::test_dec_button - AssertionError: assert '-1' == '41'
========================= 1 failed, 2 passed in 0.11s =====================
```

Pressing `-1` we expect the label to say "41" but it displays `-1`. In the test we can not only check the appearance of the label, but also inspect the internal application state and clarify if the wrong behaviour is caused by a typo or some logic bug.


## ✍️ Wrapping up

We found the error, and now it's an easy fix. When the application is really complex, it's very important to have a test suite that validates the interface behavior, because when complexity increases, manual testing gets repetitive and very error prone. For example we can easily validate that the number does not exceed limits:

{{< highlight python >}}
def test_inc_button_10_times(qtbot,widget):
    # click 10 times the + button and make sure it updates the numeric label
    for i in range(10):
        qtbot.mouseClick(widget.ui.btnInc, qt_api.QtCore.Qt.MouseButton.LeftButton)
    assert widget.ui.lbl_number.text()=="52"
    assert "background-color: green" in widget.ui.lbl_number.styleSheet()

def test_inc_button_100_times(qtbot,widget):
    # click 100 times the + button and make sure it updates the numeric label
    for i in range(100):
        qtbot.mouseClick(widget.ui.btnInc, qt_api.QtCore.Qt.MouseButton.LeftButton)
    assert widget.ui.lbl_number.text()=="100"
{{</ highlight >}}

These tests runs in 1/10th of a second and can save us from many future bugs. 

As we've seen, pytest-qt offers a powerful and efficient way to automate testing for PySide/PyQt GUI applications.  With minimal code changes, we can achieve robust test coverage and ensure consistent application behavior.  Feel free to explore the provided code example further and leverage pytest-qt in your own projects!  For  a deeper dive, consider exploring the official documentation for [pytest-qt](https://readthedocs.org/projects/pytest/) and [pytest](https://docs.pytest.org/en/latest/contents.html). While headless testing excels in functional validation, it's important to remember that it might not cover all aspects of UI testing, such as visual layout verification.

As a final hint, remember to configure your `pytest.ini` with the exact flavor of the framework:

```bash
$ cat pytest.ini 
[pytest]
qt_api=pyside6
```

Enjoy!

