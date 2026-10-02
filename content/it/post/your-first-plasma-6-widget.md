---
layout: post
title: "Il tuo primo widget per Plasma 6: C++, QML e il pattern Observer"
description: "Un regalo per il trentesimo compleanno di KDE: costruire, installare e verificare un piccolo widget per Plasma 6 con un modello in C++ e una vista in QML, per capire che cosa sono davvero segnali, slot, Observer e MVC."
categories: [programmazione, desktop]
tags: [kde, plasma, cpp, qt, qml, linux, tutorial, principianti]
author: Andrea Manzini
date: 2026-10-02
---

## 🦎 Ciao geeko!

Il 14 ottobre 1996 uno studente di nome Matthias Ettrich annunciò la nascita di un "Kool Desktop Environment" per Linux; trent'anni dopo KDE è ancora in piena attività, e un compleanno così merita di essere festeggiato come si deve. Buon trentesimo compleanno, KDE! La comunità raccoglie le iniziative per l'anniversario nella pagina [KDE at 30](https://kde.org/anniversaries/30/).

![KDE logo](/img/kde-logo.png)
Crediti immagine: il logo di KDE proviene dal [press kit di KDE](https://kde.org/stuff/clipart/) (LGPL). KDE® e il logo K Desktop Environment® sono marchi registrati di [KDE e.V.](https://ev.kde.org/)

Questo articolo è il mio regalo di compleanno: il tutorial che avrei voluto trovare quando ho provato a scrivere il mio primo widget per Plasma e mi sono perso nella documentazione. Costruiremo un piccolo widget per Plasma 6 con un modello in C++ e una vista in QML, cioè un pulsante che conta i clic: sono circa cento righe di codice, ma il progetto si compila, si installa, funziona nel pannello e ha perfino un test unitario. Lungo la strada incontreremo quattro concetti che chi sviluppa con Qt e KDE usa ogni giorno, cioè i segnali, gli slot, il pattern Observer e l'MVC.

Il codice completo è su GitHub: [ilmanzo/plasma-hello-counter](https://github.com/ilmanzo/plasma-hello-counter).

<!--more-->

Ti serve soltanto un po' di C++ di base, senza alcuna conoscenza preliminare di Qt o di KDE.

Per dovere di cronaca, esistono già altre risorse: la pagina ufficiale di KDE sui [widget con un plugin in C++](https://develop.kde.org/docs/plasma/widget/c-api/) è scritta per Plasma 5 (Qt 5, un file `qmldir` da scrivere a mano, `qmlRegisterType`), mentre il [post di Han Young](https://www.hanyoung.uk/blog/plasmoid-with-cpp/) risale al 2020. Questo tutorial usa invece Plasma 6 e Qt 6.

## 🎛️ Che cos'è un widget, in fondo?

Un widget (il nome formale è *plasmoide* oppure *applet*) è un piccolo programma che gira dentro la shell del desktop, `plasmashell`, e non ha una finestra tutta sua: sta in un pannello, nel vassoio di sistema o direttamente sul desktop. È un pacchetto composto da due tipi di file, un `metadata.json` che dice chi è il widget e alcuni file QML che ne descrivono l'aspetto, dove QML è il linguaggio di Qt per le interfacce grafiche.

Un widget può avere fino a due facce: la rappresentazione compatta è la piccola icona nel pannello, mentre la rappresentazione completa è la finestra a comparsa che si apre quando ci clicchi sopra, e se non ne scrivi una compatta Plasma mostra semplicemente l'icona del tuo widget.

Un widget scritto soltanto in QML può essere pubblicato sul KDE Store, mentre uno che contiene codice C++ no, perché include una libreria compilata e quindi arriva agli utenti attraverso i pacchetti della distribuzione. In sostanza, tutto ciò che non è banale (accesso alla rete, analisi di testi, grandi quantità di dati) può stare nel C++, e QML resta solo un sottile strato di presentazione.

Il codice C++ gira dentro `plasmashell`, quindi un crash nel tuo codice si porta dietro l'intera shell del desktop: conviene tenerlo piccolo e testarlo con cura.

## 🛎️ Quattro idee in cinque minuti

Nel codice Qt ricorrono ovunque quattro termini, perciò li definiamo prima di scrivere la prima riga.

### Segnale

Un segnale annuncia che è successo qualcosa: un pulsante emette `clicked`, un timer emette `timeout` e il nostro contatore emetterà `countChanged`. Funziona come un campanello, che emette un avviso ma non gli serve sapere chi sia in casa a sentirlo.

### Slot

Uno slot è una normale funzione che può rispondere a un segnale, come la persona che va ad aprire la porta, e lo si collega al segnale con `connect()`:

```cpp
connect(button, &Button::clicked, counter, &Counter::increment);
```

Si legge così: "quando `button` emette `clicked`, chiama `counter->increment()`".

In QML raramente serve scrivere `connect()` a mano, perché un gestore come `onClicked: ...` è già uno slot collegato a `clicked`, e un binding come `text: counter.count` (cioè una proprietà legata a un'espressione) è una connessione che QML crea al posto tuo.

### Observer

Nel pattern Observer (in italiano "osservatore") un oggetto, il soggetto, tiene un elenco di altri oggetti, gli osservatori, e li avvisa tutti quando cambia. È lo stesso principio di una newsletter: il soggetto non sa che cosa facciano gli iscritti delle notizie che ricevono, quindi puoi aggiungere un iscritto senza toccare il soggetto. Qt ha questo pattern già incorporato, perché i segnali e gli slot *sono* il pattern Observer, con il segnale al posto della newsletter e le connessioni al posto dell'elenco degli iscritti.

### MVC

Il Model-View-Controller divide un programma in tre ruoli, e un ristorante li illustra bene. Il modello è la cucina: contiene i dati e le regole, e non ha idea di come sia fatta la sala. La vista è ciò che arriva in tavola, cioè mostra il modello al cliente senza fare altro. Il controller è il cameriere, che trasforma i desideri del cliente in ordini per la cucina. Qt ha anche classi chiamate "model/view", come `QAbstractListModel`, che sono un cugino più specifico della stessa idea, pensato per elenchi e tabelle, e che oggi non ci servono.

Il diagramma associa questi ruoli al nostro widget:

```
   user clicks
        │
        ▼
 ┌───────────────────────┐
 │ Button { onClicked }  │   Controller (QML): input → model call
 └──────────┬────────────┘
            │ counter.increment()
            ▼
 ┌───────────────────────┐
 │ Counter (C++)         │   Model: owns `count`
 └──────────┬────────────┘
            │ emits countChanged()      ← the signal (Observer)
   ┌────────┼──────────────────┐
   ▼        ▼                  ▼
 Heading   Tooltip         Reset button      Views (QML): only display
 text      text            enabled
```

Il modello non nomina mai una vista: puoi toglierne una o aggiungerne una quarta e `Counter` resta identico.

## 🌳 Il progetto

Il progetto è composto da questi file:

```
plasma-hello-counter/
├── CMakeLists.txt                  build + install
├── src/
│   ├── counter.h                   the model
│   └── counter.cpp
├── package/
│   ├── metadata.json               widget identity
│   └── contents/ui/main.qml        the views and the controller
└── autotests/
    ├── CMakeLists.txt
    └── countertest.cpp             a unit test
```

Seguiamo le convenzioni di KDE: lo [stile di codifica di KDE Frameworks](https://community.kde.org/Policies/Frameworks_Coding_Style) per C++ e QML, le [KDE Human Interface Guidelines](https://develop.kde.org/hig/) per l'interfaccia (icone del tema, etichette con la maiuscola soltanto all'inizio, ogni stringa visibile passata da `i18n()`) e un'intestazione SPDX con la licenza in ogni file. La licenza è `GPL-2.0-or-later`, la stessa dei widget di Plasma: i loro `metadata.json` riportano `GPL-2.0+`, che è il vecchio nome SPDX della stessa licenza.

## 🍳 Primo passo: il modello, in C++

Il modello è una classe chiamata `Counter`. Questo è `src/counter.h`:

```cpp
#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

/**
 * The model: it owns the data and knows nothing about how it is shown.
 */
class Counter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit Counter(QObject *parent = nullptr);

    int count() const;

public Q_SLOTS:
    void increment();
    void reset();

Q_SIGNALS:
    void countChanged();

private:
    int m_count = 0;
};
```

I nomi che iniziano con `Q` vengono da Qt. `QObject` è la classe base di tutto ciò che può avere segnali e slot; `Q_OBJECT` accende il meccanismo, perché uno strumento di compilazione chiamato `moc` legge il file di intestazione e genera il codice che sta dietro a segnali e slot (CMake lo esegue al posto tuo); `QML_ELEMENT` rende la classe disponibile in QML con il nome `Counter`.

`Q_PROPERTY(int count READ count NOTIFY countChanged)` dichiara una proprietà di nome `count`: la leggi con `count()`, e il tuo codice deve emettere `countChanged` ogni volta che il valore cambia, perché QML si iscrive a quel segnale e così sa quando aggiornarsi. `Q_SLOTS` contrassegna le funzioni che si possono collegare ai segnali (anche QML può chiamarle), mentre `Q_SIGNALS` dichiara i segnali, di cui scrivi soltanto la dichiarazione perché il corpo lo genera `moc`.

Il codice di KDE usa `Q_SLOTS`, `Q_SIGNALS` e `Q_EMIT` e mai le parole minuscole `slots`, `signals` ed `emit`, che la compilazione di KDE disattiva (`QT_NO_KEYWORDS`) perché entrano in conflitto con altre librerie.

Questo è `src/counter.cpp`:

```cpp
#include "counter.h"

Counter::Counter(QObject *parent)
    : QObject(parent)
{
}

int Counter::count() const
{
    return m_count;
}

void Counter::increment()
{
    ++m_count;
    Q_EMIT countChanged();
}

void Counter::reset()
{
    if (m_count == 0) {
        return;
    }

    m_count = 0;
    Q_EMIT countChanged();
}
```

`Q_EMIT countChanged()` fa suonare il campanello. Quando il conteggio è già zero, `reset()` ritorna senza emettere niente: un segnale dice che qualcosa è cambiato, quindi va emesso solo quando è cambiato davvero, altrimenti tutti gli osservatori si svegliano per niente.

## 🍽️ Secondo passo: le viste e il controller, in QML

Il file `package/metadata.json` dice a Plasma chi è il nostro widget:

```json
{
    "KPlugin": {
        "Id": "org.opensuse.hellocounter",
        "Name": "Hello counter",
        "Description": "Counts how many times you click a button",
        "Icon": "accessories-calculator",
        "Authors": [
            {
                "Name": "Andrea Manzini"
            }
        ],
        "Category": "Utilities",
        "License": "GPL-2.0-or-later",
        "Version": "0.1.0"
    },
    "KPackageStructure": "Plasma/Applet",
    "X-Plasma-API-Minimum-Version": "6.0"
}
```

`X-Plasma-API-Minimum-Version` è obbligatoria: senza di essa Plasma presume che si tratti di un widget per Plasma 5 e lo nasconde. L'`Icon` è ciò che il pannello mostra finché non clicchi, e ci regala la rappresentazione compatta senza altro lavoro.

Ora tocca a `package/contents/ui/main.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.opensuse.hellocounter

PlasmoidItem {
    id: root

    // The model, created once per widget instance
    Counter {
        id: counter
    }

    // View 1: the tooltip shown when hovering the tray icon
    toolTipMainText: i18n("Hello counter")
    toolTipSubText: i18np("%1 click", "%1 clicks", counter.count)

    // View 2: the popup
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 5
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            text: i18np("%1 click", "%1 clicks", counter.count)
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            // The controller: turns user input into calls on the model
            PlasmaComponents.Button {
                icon.name: "list-add"
                text: i18n("Click me")
                onClicked: counter.increment()
            }

            PlasmaComponents.Button {
                icon.name: "edit-reset"
                text: i18n("Reset")
                enabled: counter.count > 0
                onClicked: counter.reset()
            }
        }
    }
}
```

La radice di un widget per Plasma 6 deve essere un `PlasmoidItem`, e il file deve chiamarsi `contents/ui/main.qml`. `import org.opensuse.hellocounter` è il modo in cui QML trova la nostra classe C++, e `Counter { id: counter }` crea un oggetto modello, proprio come in C++. `i18n()` e `i18np()` (la "n" sta per plurale) marcano le stringhe visibili come traducibili, per cui `i18np("%1 click", "%1 clicks", n)` produce "1 click" oppure "2 clicks". I colori, le spaziature e le icone provengono dal tema, senza colori scritti a mano, così il widget segue la combinazione di colori e il carattere scelti dall'utente.

Prova a cercare il codice che aggiorna l'etichetta dopo un clic: non c'è. Il `text` dell'intestazione è un binding, quindi QML vede che dipende da `counter.count`, si iscrive a `countChanged` e lo valuta di nuovo ogni volta che il segnale scatta. L'intestazione, il suggerimento a comparsa e lo stato abilitato del pulsante Reset sono tre *osservatori* dello stesso modello, e nessuno di loro richiede codice di aggiornamento, il che spiega anche perché il modello può restare così piccolo: non ha bisogno di sapere chi notificare quando viene cambiato.

## 🧰 Terzo passo: la compilazione con CMake

Questo è un `CMakeLists.txt` abbreviato, senza il target `clang-format` e senza un messaggio che il passo di installazione stampa:

```cmake
cmake_minimum_required(VERSION 3.20)

project(plasma-hello-counter VERSION 0.1.0 LANGUAGES CXX)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Qml)

# The C++ part: a QML module "org.opensuse.hellocounter" holding the Counter type
add_library(hellocounter)
ecm_add_qml_module(hellocounter URI "org.opensuse.hellocounter" VERSION 1.0 GENERATE_PLUGIN_SOURCE PLUGIN_TARGET hellocounter)
target_sources(hellocounter PRIVATE src/counter.cpp src/counter.h)
target_include_directories(hellocounter PRIVATE src)
target_link_libraries(hellocounter PRIVATE Qt6::Qml)
ecm_finalize_qml_module(hellocounter)

# The QML part: the plasmoid package
install(DIRECTORY package/
    DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/org.opensuse.hellocounter
)

if (BUILD_TESTING)
    include(ECMAddTests)
    add_subdirectory(autotests)
endif()
```

ECM, abbreviazione di Extra CMake Modules, è la raccolta di strumenti CMake di KDE: `KDEInstallDirs` sa dove vanno installate le cose sulla tua distribuzione (`lib64` oppure `lib`), `KDECMakeSettings` attiva `moc` e `KDECompilerSettings` aggiunge le opzioni, molto rigorose, con cui si compila il codice di KDE.

`ecm_add_qml_module` crea il plugin C++: scrive il file `qmldir` e la classe del plugin e registra ogni classe `QML_ELEMENT`, per cui non servono né un `plugin.cpp` né una chiamata a `qmlRegisterType`. `ecm_finalize_qml_module` installa il risultato in `<prefix>/lib64/qml/org/opensuse/hellocounter/`, e l'ultimo `install(DIRECTORY ...)` mette il pacchetto del widget in `<prefix>/share/plasma/plasmoids/<id>`.

## 🛫 Compilare, installare ed eseguire

Installa prima gli strumenti di compilazione. Questi elenchi di pacchetti bastano per compilare, eseguire i test e installare il progetto, e li ho provati tutti in un container pulito.

openSUSE Tumbleweed:

```bash
sudo zypper in cmake gcc-c++ kf6-extra-cmake-modules qt6-qml-devel qt6-test-devel
```

Debian 13:

```bash
sudo apt install cmake g++ make extra-cmake-modules qt6-declarative-dev qt6-base-dev
```

Fedora:

```bash
sudo dnf install cmake gcc-c++ make extra-cmake-modules qt6-qtdeclarative-devel qt6-qtbase-devel
```

Il pacchetto `qt6-test-devel` serve soltanto per il test unitario; su Debian e Fedora il pacchetto di sviluppo di base lo include già.

Poi clona il repository, compila, esegui i test e installa:

```bash
git clone https://github.com/ilmanzo/plasma-hello-counter.git
cd plasma-hello-counter
cmake -B build -DCMAKE_INSTALL_PREFIX=~/.local
cmake --build build --parallel
ctest --test-dir build --output-on-failure
cmake --install build
```

L'installazione avviene in `~/.local`, quindi non servono i privilegi di root, ed è proprio lì che abbiamo il primo problema.

### 🗺️ La variabile d'ambiente che dimenticherai

Il widget finisce in due posti:

| Parte | Installata in | Chi la trova |
|---|---|---|
| Pacchetto QML | `~/.local/share/plasma/plasmoids/org.opensuse.hellocounter` | Plasma, in automatico |
| Modulo C++ `org.opensuse.hellocounter` | `~/.local/lib64/qml/org/opensuse/hellocounter` | Qt, solo se gli indichi dove cercare |

Qt cerca i moduli QML soltanto nelle proprie directory di sistema, per cui un modulo sotto `~/.local` resta invisibile finché non imposti `QML_IMPORT_PATH` sulla directory `qml`. Senza di essa il widget si rifiuta di caricarsi:

```
module "org.opensuse.hellocounter" is not installed
```

Usa la directory che `cmake --install` ha stampato: `~/.local/lib64/qml` su openSUSE e Fedora, `~/.local/lib/x86_64-linux-gnu/qml` su Debian e Ubuntu. Il passo di installazione stampa anche un promemoria con il percorso esatto.

Per una prova veloce in una finestra a sé stante, esegui:

```bash
env QML_IMPORT_PATH=$HOME/.local/lib64/qml plasmawindowed org.opensuse.hellocounter
```

`env VARIABILE=valore comando` funziona allo stesso modo in bash e in fish. Aggiungi `QT_FORCE_STDERR_LOGGING=1` per vedere gli errori di QML nel terminale, perché Qt manda i propri messaggi al journal quando lo standard error non è un terminale. Tieni presente anche che `plasmawindowed` ammette una sola istanza per widget: se esiste già una finestra aperta, un secondo comando passa la mano a quella finestra ed esce, e la cosa sembra un successo.

Per usare il widget in un pannello o sul desktop la variabile deve raggiungere `plasmashell`, ma a lanciarlo è la tua sessione di login e non la shell, quindi una variabile esportata in un terminale non gli arriva. Mettila dove la cerca la sessione:

```bash
mkdir -p ~/.config/plasma-workspace/env
echo 'export QML_IMPORT_PATH=$HOME/.local/lib64/qml' > ~/.config/plasma-workspace/env/hello-counter.sh
```

Poi esci dalla sessione e accedi di nuovo, fai clic con il tasto destro sul desktop o su un pannello, scegli *Aggiungi o gestisci oggetti…* (Plasma in italiano chiama "oggetti" i widget), cerca "Hello counter" e aggiungilo. Fai clic sull'icona, poi sul pulsante e infine passa il puntatore sull'icona: anche il suggerimento a comparsa conta i clic.

Un'installazione di sistema (`-DCMAKE_INSTALL_PREFIX=/usr` oppure un pacchetto della distribuzione) non richiede nulla di tutto ciò, perché Qt cerca già in quei percorsi. A chi usa il tuo widget non servirà mai questa variabile, mentre a te servirà impostarla ogni volta che proverai una compilazione locale.

## 🕵️ Mettere alla prova il segnale

Per verificare che `Counter` emetta davvero `countChanged`, lasciamo che sia Qt ad ascoltare il segnale. Questo è `autotests/countertest.cpp`, scritto con [Qt Test](https://doc.qt.io/qt-6/qtest-overview.html), il framework di test usato da KDE:

```cpp
#include "counter.h"

#include <QSignalSpy>
#include <QTest>

class CounterTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void incrementEmitsCountChanged();
    void resetEmitsOnlyWhenCountChanges();
};

void CounterTest::incrementEmitsCountChanged()
{
    Counter counter;
    QSignalSpy spy(&counter, &Counter::countChanged);

    counter.increment();
    counter.increment();

    QCOMPARE(counter.count(), 2);
    QCOMPARE(spy.count(), 2);
}

void CounterTest::resetEmitsOnlyWhenCountChanges()
{
    Counter counter;
    QSignalSpy spy(&counter, &Counter::countChanged);

    counter.reset(); // already 0: nothing to announce
    QCOMPARE(spy.count(), 0);

    counter.increment();
    counter.reset();
    QCOMPARE(counter.count(), 0);
    QCOMPARE(spy.count(), 2);
}

QTEST_GUILESS_MAIN(CounterTest)

#include "countertest.moc"
```

`QSignalSpy` è un osservatore già pronto: si collega a un segnale e conta quante volte scatta. Anche le funzioni di test sono slot, e Qt Test esegue ogni funzione della sezione `private Q_SLOTS`. Lancialo con:

```bash
ctest --test-dir build --output-on-failure
```

Un test che non può fallire non dimostra nulla, quindi rompiamo il codice di proposito. Cancella la guardia `if (m_count == 0) { return; }` da `reset()`, ricompila ed esegui il test: fallisce. Rimetti la guardia, cancella `Q_EMIT countChanged();` da `increment()`, ricompila ed esegui di nuovo il test: fallisce ancora. Ho fatto entrambe le prove prima di pubblicare questo post.

## 🩹 Le trappole in cui sono caduto

Il widget si rifiuta di caricarsi con `module "org.opensuse.hellocounter" is not installed`: Qt non cerca nella tua directory di installazione, quindi imposta `QML_IMPORT_PATH` come descritto sopra.

La compilazione si ferma con `'Counter' was not declared in this scope`: il file di registrazione generato include `<counter.h>` e non riesce a trovarlo, ma `target_include_directories(hellocounter PRIVATE src)` risolve il problema.

`ldd` mostra `libhellocounter.so => not found` per il plugin installato: di default `ecm_add_qml_module` costruisce due librerie, una con il tuo codice e un plugin che dipende da essa, e il passo di installazione copia soltanto il plugin, mentre `PLUGIN_TARGET hellocounter` ti dà una libreria unica.

CMake si ferma con `ecm_add_test() called with multiple source files but without setting "TEST_NAME"`: il nostro test compila due file, `countertest.cpp` e `counter.cpp`, quindi bisogna aggiungere `TEST_NAME countertest`.

Il widget manca dall'elenco dei widget: controlla che `metadata.json` contenga `X-Plasma-API-Minimum-Version`, perché senza di essa Plasma lo considera un widget per Plasma 5 e lo nasconde. Anche la radice deve essere un `PlasmoidItem`, mentre i tutorial più vecchi usano un semplice `Item`.

## 🎁 Per concludere

Ora hai un modello in C++, una vista con il suo controller in QML, un test e una compilazione che installa il tutto, e da qui si può proseguire in molte direzioni.

Plasma può memorizzare le impostazioni, quindi il conteggio può sopravvivere a un riavvio: descrivile in `contents/config/main.xml` e leggile con `Plasmoid.configuration`. Il modello può anche lavorare da solo: un timer nel costruttore di `Counter` è il `connect()` C++ visto prima e trasforma il widget in un cronometro senza toccare il QML:

```cpp
auto *timer = new QTimer(this);
connect(timer, &QTimer::timeout, this, &Counter::increment);
timer->start(std::chrono::seconds(1));
```

I tre osservatori continuano ad aggiornarsi e le viste restano le stesse. Se invece di un singolo numero vuoi un elenco, usa un `QAbstractListModel` come modello e una `ListView` di QML come vista, mantenendo gli stessi tre ruoli; un modello può anche scaricare dati con `QNetworkAccessManager` mentre le viste restano semplici. Quando il widget è pronto per altre persone, un pacchetto della distribuzione installa il modulo in un percorso in cui Qt cerca, così gli utenti non incontrano mai `QML_IMPORT_PATH`.

Il [tutorial ufficiale sui widget di Plasma](https://develop.kde.org/docs/plasma/widget/) e la [guida al porting a Plasma 6](https://develop.kde.org/docs/plasma/widget/porting_kf6/) trattano il resto.

Buon trentesimo compleanno, KDE, e grazie per tre decenni di software libero. Happy hacking!
