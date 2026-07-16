---
layout: post
description: "Un approccio al testing headless di programmi GUI"
title: "Testing Headless di Applicazioni GUI PySide/PyQt con pytest-qt"
categories: linux
tags: [linux, python, tutorial, qt, testing, unit testing, gui, programming]
author: Andrea Manzini
date: 2024-05-22
---

## 🤓 Introduzione

Il testing manuale delle applicazioni GUI può diventare noioso e soggetto a errori con l'aumento delle funzionalità e della complessità. Il testing headless offre una soluzione automatizzando le interazioni dell'interfaccia utente (UI) senza la necessità di un display fisico. Questo approccio consente un'esecuzione più rapida dei test, una migliore ripetibilità e una perfetta integrazione con le pipeline di continuous integration e continuous delivery (CI/CD). In questo post esploreremo come sfruttare pytest-qt, un potente framework per il testing headless di applicazioni [PySide/PyQt](https://wiki.qt.io/Qt_for_Python).

Come al solito, tutto il codice è disponibile nel mio [repository GitHub](https://github.com/ilmanzo/pyside-playground/tree/master/testable_app).

## 🧮 Esempio

Come punto di partenza, supponiamo di avere un'app piuttosto semplice, composta solo da due pulsanti e un'etichetta (label).

![crappycounter0](/img/crappycounter0.png)

Sì, il [giorno dell'asciugamano (Towel Day)](https://en.wikipedia.org/wiki/Towel_Day) si avvicina.

## 🤬 Il problema

L'applicazione è piuttosto semplice: un'etichetta numerica che dovrebbe essere rossa quando mostra numeri dispari, verde per i numeri pari. L'utente può solo incrementare o decrementare il contatore con i pulsanti corrispondenti. 

Quando premiamo il pulsante `+1`, il numero aumenta correttamente:

![crappycounter1](/img/crappycounter1.png)

Un utente ci mostra gentilmente il problema: quando premiamo il pulsante `-1`, *succede qualcosa di strano!*

![crappycounter2](/img/crappycounter2.png)

Probabilmente per questo semplice problema potremmo limitarci a ispezionare il codice e trovare l'errore in pochissimo tempo, ma dato che siamo dei tester, vogliamo aggiungere alcuni test alla nostra applicazione interattiva.

## 🧑‍🔬 Il primo test

Per convalidare l'errore, utilizzeremo il plugin [pytest-qt](https://pytest-qt.readthedocs.io/en/latest/) per il framework [pytest](https://docs.pytest.org/). Creare un test per riprodurre il problema non solo ci aiuta a individuare l'errore specifico, ma contribuisce a creare una suite di test in crescita che preverrà anche future regressioni.

Iniziamo con un test semplice: l'applicazione deve essere in grado di avviarsi e il valore iniziale del contatore deve essere 42. Con `pytest` si tratta di una sola funzione:

{{< highlight python >}}
from mainwindow import MainWindow

def test_application_start(qtbot):
    widget = MainWindow()
    qtbot.addWidget(widget)
    assert widget.number == 42
{{</ highlight >}}	

`qtbot` è una *Fixture* decisamente comoda fornita dal plugin `pytest-qt`; per "eseguire" la nostra app dobbiamo semplicemente aggiungere il nostro widget all'oggetto `qtbot`.

esecuzione del test:

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


Successo! Come potete vedere, la *Fixture* `pytest-qt` gestisce per noi tutti i dettagli più noiosi relativi all'istanziazione di una *QApplication* e all'esecuzione di un event loop in ascolto di signal/slot. La GUI non viene nemmeno renderizzata sullo schermo, rendendo questo approccio adatto all'esecuzione anche in un ambiente automatizzato come una CI.

## ✅ Il secondo test

Aggiungiamo un secondo test: diciamo all'applicazione di "premere" il pulsante +1 e ci aspettiamo sia il numero corretto che l'attributo colore dell'etichetta:

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

Abbiamo anche rifattorizzato la parte comune, fornendo una fixture di `setup` del widget che gestisce lo stato iniziale per ciascun test. Anche la seconda esecuzione è verde:

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

## 🐞 Un test fallito

Ci manca solo il terzo test, che dovrebbe innescare il problema:

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

**AHA!** (portate pazienza, per un ingegnere QA un test che fallisce è pura felicità) 

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

Premendo `-1` ci aspettiamo che l'etichetta mostri "41", ma mostra `-1`. Nel test possiamo non solo verificare l'aspetto dell'etichetta, ma anche ispezionare lo stato interno dell'applicazione e chiarire se il comportamento errato sia causato da un errore di battitura o da qualche bug logico.


## ✍️ Conclusioni

Abbiamo trovato l'errore e ora risolverlo è un gioco da ragazzi. Quando l'applicazione è davvero complessa, è fondamentale disporre di una suite di test che convalidi il comportamento dell'interfaccia, perché all'aumentare della complessità il testing manuale diventa ripetitivo e molto soggetto a errori. Ad esempio, possiamo facilmente verificare che il numero non superi i limiti:

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

Questi test vengono eseguiti in un decimo di secondo e possono salvarci da molti futuri bug. 

Come abbiamo visto, pytest-qt offre un modo potente ed efficiente per automatizzare i test per le applicazioni GUI PySide/PyQt. Con modifiche minime al codice, possiamo ottenere una robusta copertura di test e garantire un comportamento coerente dell'applicazione. Sentitevi liberi di esplorare ulteriormente l'esempio di codice fornito e di sfruttare pytest-qt nei vostri progetti! Per un approfondimento, prendete in considerazione l'esplorazione della documentazione ufficiale di [pytest-qt](https://readthedocs.org/projects/pytest/) e [pytest](https://docs.pytest.org/en/latest/contents.html). Sebbene il testing headless eccella nella convalida funzionale, è importante ricordare che potrebbe non coprire tutti gli aspetti del testing della UI, come la verifica del layout visivo.

Come ultimo suggerimento, ricordatevi di configurare il vostro file `pytest.ini` con la versione specifica del framework:

```bash
$ cat pytest.ini 
[pytest]
qt_api=pyside6
```

Buon divertimento!
