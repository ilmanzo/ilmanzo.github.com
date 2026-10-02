---
layout: post
title: "Your first Plasma 6 widget: C++, QML and the Observer pattern"
description: "A birthday present for KDE's 30th: build, install and test a small Plasma 6 widget with a C++ model and a QML view, and learn what signals, slots, Observer and MVC mean."
categories: [programming, desktop]
tags: [kde, plasma, cpp, qt, qml, linux, tutorial, beginners]
author: Andrea Manzini
date: 2026-10-02
---

## 🦎 Hi geekos!

On 14 October 1996 a student called Matthias Ettrich announced a "Kool Desktop Environment" for Linux. Thirty years later KDE is still going, so happy 30th birthday, KDE! The community collects the celebrations on the [KDE at 30](https://kde.org/anniversaries/30/) page.

![KDE logo](/img/kde-logo.png)
Image credits: KDE logo from the [KDE press kit](https://kde.org/stuff/clipart/) (LGPL). KDE® and the K Desktop Environment® logo are registered trademarks of [KDE e.V.](https://ev.kde.org/)

This post is my birthday present: the tutorial I wanted when I tried to write my first Plasma widget and got lost in the docs. We will build a small Plasma 6 widget with a C++ model and a QML view, a button that counts clicks. It is about 100 lines of code, and it builds, installs, runs in your panel and has a unit test. On the way we meet four ideas that Qt and KDE developers use daily: signals, slots, the Observer pattern and MVC.

The complete code is on GitHub: [ilmanzo/plasma-hello-counter](https://github.com/ilmanzo/plasma-hello-counter).

<!--more-->

You need basic C++ and nothing else. Qt and KDE knowledge is not required.

Prior art: the official KDE page about [widgets with a C++ plugin](https://develop.kde.org/docs/plasma/widget/c-api/) is written for Plasma 5 (Qt 5, a handwritten `qmldir`, `qmlRegisterType`), and [Han Young's post](https://www.hanyoung.uk/blog/plasmoid-with-cpp/) is from 2020. This tutorial uses Plasma 6 and Qt 6.

## 🎛️ What's a widget, anyway?

A widget (officially a *plasmoid* or *applet*) is a small program that runs inside the desktop shell, `plasmashell`. It has no window of its own and sits in a panel, in the system tray or on the desktop. It is a package with two kinds of file: a `metadata.json` that says who the widget is, and QML files that describe how it looks. QML is the UI language of Qt.

A widget has up to two faces. The compact representation is the small icon in the panel, and the full representation is the popup that opens when you click it. If you skip the compact one, Plasma shows the icon of your widget.

A pure QML widget can go to the KDE Store. A widget with C++ code cannot, because it ships a compiled library, so it reaches users through distribution packages. In exchange, anything non-trivial (networking, parsing, a lot of data) can go into C++, and QML stays a thin display layer.

The C++ code runs inside `plasmashell`, so a crash in your code takes the desktop shell down with it. Keep it small and test it.

## 🛎️ Four ideas in five minutes

Four terms show up everywhere in Qt code, so we define them before the first line.

### Signal

A signal announces that something happened. A button emits `clicked`, a timer emits `timeout`, and our counter will emit `countChanged`. It works like a doorbell: it rings, and it does not know who is at home to hear it.

### Slot

A slot is an ordinary function that can answer a signal, like the person who walks to the door. You connect the two with `connect()`:

```cpp
connect(button, &Button::clicked, counter, &Counter::increment);
```

Read it as "when `button` emits `clicked`, call `counter->increment()`".

In QML you rarely write `connect()` yourself. An `onClicked: ...` handler is a slot that is already connected to `clicked`, and a binding such as `text: counter.count` is a connection that QML creates for you.

### Observer

In the Observer pattern an object (the subject) keeps a list of other objects (the observers) and tells all of them when it changes. A newsletter works the same way. The subject does not know what the subscribers do with the news, so you can add a subscriber without touching the subject. Qt has this pattern built in: signals and slots are the Observer pattern, with the signal as the newsletter and the connections as the subscriber list.

### MVC

Model-View-Controller splits a program into three roles, and a restaurant shows them well. The model is the kitchen: the data and the rules, with no idea what the dining room looks like. The view is what arrives on the table: it shows the model to the customer and does nothing else. The controller is the waiter, who turns what the customer wants into orders for the kitchen. Qt also has classes called "model/view", such as `QAbstractListModel`. They are a more specific cousin of the same idea, made for lists and tables, and we do not need them today.

The diagram maps these roles to our widget:

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

The model never mentions a view. You can remove one or add a fourth, and `Counter` stays the same.

## 🌳 The project

The project has these files:

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

We follow the KDE conventions: the [KDE Frameworks coding style](https://community.kde.org/Policies/Frameworks_Coding_Style) for C++ and QML, the [KDE Human Interface Guidelines](https://develop.kde.org/hig/) for the interface (theme icons, sentence-case labels, every visible string through `i18n()`), and an SPDX license header on every file. The license is `GPL-2.0-or-later`, like Plasma's own widgets. Their `metadata.json` says `GPL-2.0+`, the old SPDX spelling of the same license.

## 🍳 Step 1: the model, in C++

The model is a class called `Counter`. This is `src/counter.h`:

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

The `Q` names come from Qt. `QObject` is the base class of everything that can have signals and slots. `Q_OBJECT` switches the machinery on: a build tool called `moc` reads the header and generates the code behind signals and slots, and CMake runs it for you. `QML_ELEMENT` makes the class available in QML as `Counter`.

`Q_PROPERTY(int count READ count NOTIFY countChanged)` declares a property named `count`. You read it with `count()`, and your code must emit `countChanged` every time the value changes. QML subscribes to that signal, which is how it knows when to refresh. `Q_SLOTS` marks the functions that can be connected to signals (QML can call them too), and `Q_SIGNALS` declares signals. You write only the declaration of a signal, and `moc` writes the body.

KDE code spells these `Q_SLOTS`, `Q_SIGNALS` and `Q_EMIT` and never uses the lowercase `slots`, `signals` and `emit`. The KDE build turns the lowercase keywords off (`QT_NO_KEYWORDS`) because they clash with other libraries.

This is `src/counter.cpp`:

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

`Q_EMIT countChanged()` rings the doorbell. When the count is already zero, `reset()` returns without emitting anything. A signal says that something changed, so emit it only when something did, otherwise every observer wakes up for nothing.

## 🍽️ Step 2: the views and the controller, in QML

`package/metadata.json` tells Plasma who the widget is:

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

`X-Plasma-API-Minimum-Version` is mandatory. Without it Plasma assumes a Plasma 5 widget and hides yours. The `Icon` is what the panel shows until you click, which gives us the compact representation for free.

Now `package/contents/ui/main.qml`:

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

The root of a Plasma 6 widget must be a `PlasmoidItem`, and the file must be `contents/ui/main.qml`. `import org.opensuse.hellocounter` is how QML finds our C++ class, and `Counter { id: counter }` creates one model object, like in C++. `i18n()` and `i18np()` ("n" for plural) mark visible strings as translatable, so `i18np("%1 click", "%1 clicks", n)` gives "1 click" or "2 clicks". Colors, spacing and icons come from the theme, with no hard coded colors, so the widget follows the color scheme and the font of the user.

Try to find the code that refreshes the label after a click. There isn't any. The `text` of the heading is a binding: QML sees that it depends on `counter.count`, subscribes to `countChanged`, and evaluates it again whenever the signal fires. The heading, the tooltip and the enabled state of the Reset button are three observers of the same model, and none of them needs refresh code. This is also why the model can stay so small.

## 🧰 Step 3: the build, with CMake

This is a trimmed `CMakeLists.txt`, without the `clang-format` target and a message that the install step prints:

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

ECM, short for Extra CMake Modules, is KDE's collection of CMake helpers. `KDEInstallDirs` knows where things go on your distribution (`lib64` or `lib`), `KDECMakeSettings` turns on `moc`, and `KDECompilerSettings` adds the strict compiler flags that KDE code uses.

`ecm_add_qml_module` creates the C++ plugin. It writes the `qmldir` file and the plugin class and registers every `QML_ELEMENT` class, so we need no `plugin.cpp` and no `qmlRegisterType` call. `ecm_finalize_qml_module` installs the result in `<prefix>/lib64/qml/org/opensuse/hellocounter/`. The last `install(DIRECTORY ...)` puts the widget package in `<prefix>/share/plasma/plasmoids/<id>`.

## 🛫 Build, install and run

Install the build tools first. These package lists are enough to build, test and install the project, and I tried each of them in a clean container.

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

`qt6-test-devel` is only for the unit test. On Debian and Fedora the base development package includes it.

Then clone, build, test and install:

```bash
git clone https://github.com/ilmanzo/plasma-hello-counter.git
cd plasma-hello-counter
cmake -B build -DCMAKE_INSTALL_PREFIX=~/.local
cmake --build build --parallel
ctest --test-dir build --output-on-failure
cmake --install build
```

The install goes to `~/.local`, which needs no root, and that is also where the first problem appears.

### 🗺️ The environment variable you will forget

The widget goes to two places:

| Part | Installed to | Found by |
|---|---|---|
| QML package | `~/.local/share/plasma/plasmoids/org.opensuse.hellocounter` | Plasma, automatically |
| C++ module `org.opensuse.hellocounter` | `~/.local/lib64/qml/org/opensuse/hellocounter` | Qt, only if you tell it where |

Qt searches only its own system directories for QML modules, so a module under `~/.local` stays invisible until you set `QML_IMPORT_PATH` to the `qml` directory. Without it the widget refuses to load:

```
module "org.opensuse.hellocounter" is not installed
```

Use the directory that `cmake --install` printed: `~/.local/lib64/qml` on openSUSE and Fedora, `~/.local/lib/x86_64-linux-gnu/qml` on Debian and Ubuntu. The install step also prints a reminder with the exact path.

For a quick try in a standalone window, run:

```bash
env QML_IMPORT_PATH=$HOME/.local/lib64/qml plasmawindowed org.opensuse.hellocounter
```

`env VAR=value command` works the same in bash and fish. Add `QT_FORCE_STDERR_LOGGING=1` to see QML errors in the terminal, because Qt sends its messages to the journal when stderr is not a terminal. Keep in mind that `plasmawindowed` allows one instance per widget: if a window for it is already open, a second command hands over to that window and exits, which looks like a success.

To use the widget in a panel or on the desktop, the variable has to reach `plasmashell`. Your login session starts it, not your shell, so a variable exported in a terminal does not arrive. Put it where the session reads it:

```bash
mkdir -p ~/.config/plasma-workspace/env
echo 'export QML_IMPORT_PATH=$HOME/.local/lib64/qml' > ~/.config/plasma-workspace/env/hello-counter.sh
```

Then log out and log in again, right-click the desktop or a panel, choose *Add or manage widgets…*, search for "Hello counter" and add it. Click the icon, click the button, and hover the icon: the tooltip counts too.

A system-wide install (`-DCMAKE_INSTALL_PREFIX=/usr`, or a distribution package) needs none of this, because Qt already searches there. Your users will never see the variable, but you will every time you test a local build.

## 🕵️ Test the signal

To check that `Counter` emits `countChanged`, let Qt listen to the signal. This is `autotests/countertest.cpp`, written with [Qt Test](https://doc.qt.io/qt-6/qtest-overview.html), the test framework that KDE uses:

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

`QSignalSpy` is a ready-made observer: it connects to a signal and counts how many times it fired. The test functions are slots too, and Qt Test runs every function in the `private Q_SLOTS` section. Run it with:

```bash
ctest --test-dir build --output-on-failure
```

A test that cannot fail proves nothing, so break the code on purpose. Delete the guard `if (m_count == 0) { return; }` from `reset()`, rebuild and run the test: it fails. Put the guard back, delete `Q_EMIT countChanged();` from `increment()`, rebuild and run again: it fails again. I did both before publishing this post.

## 🩹 Traps I fell into

The widget refuses to load with `module "org.opensuse.hellocounter" is not installed`. Qt does not search your install directory, so set `QML_IMPORT_PATH` as described above.

The build stops with `'Counter' was not declared in this scope`. The generated registration file includes `<counter.h>` and cannot find it, and `target_include_directories(hellocounter PRIVATE src)` fixes that.

`ldd` shows `libhellocounter.so => not found` for the installed plugin. By default `ecm_add_qml_module` builds two libraries, one with your code and a plugin that links to it, and the install step copies only the plugin. `PLUGIN_TARGET hellocounter` gives you a single library.

CMake stops with `ecm_add_test() called with multiple source files but without setting "TEST_NAME"`. Our test compiles two files, `countertest.cpp` and `counter.cpp`, so add `TEST_NAME countertest`.

The widget is missing from the list of widgets. Check that `metadata.json` has `X-Plasma-API-Minimum-Version`, because without it Plasma assumes a Plasma 5 widget and hides it. The root item must also be a `PlasmoidItem`, while older tutorials use a plain `Item`.

## 🎁 Wrapping up

You now have a C++ model, a QML view and controller, a test, and a build that installs it all. There are several ways to continue from here.

Plasma can store settings, so the count can survive a restart: describe them in `contents/config/main.xml` and read them with `Plasmoid.configuration`. The model can also work alone. A timer in the constructor of `Counter` is the C++ `connect()` from earlier, and it turns the widget into a stopwatch without touching the QML:

```cpp
auto *timer = new QTimer(this);
connect(timer, &QTimer::timeout, this, &Counter::increment);
timer->start(std::chrono::seconds(1));
```

The three observers still update and the views stay the same. If you want a list instead of a single number, use a `QAbstractListModel` as the model and a QML `ListView` as the view, with the same three roles. A model can fetch data with `QNetworkAccessManager` while the views stay simple. When the widget is ready for other people, a distribution package installs the module in a path that Qt searches, so users never meet `QML_IMPORT_PATH`.

The official [Plasma widget tutorial](https://develop.kde.org/docs/plasma/widget/) and the [Plasma 6 porting guide](https://develop.kde.org/docs/plasma/widget/porting_kf6/) cover the rest.

Happy 30th birthday, KDE, and thanks for three decades of free software. Happy hacking!
