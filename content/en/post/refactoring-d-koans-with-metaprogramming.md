---
layout: post
title: "Refactoring the D Koans with metaprogramming"
description: "How metaprogramming helped create a cleaner testing experience for D Koans"
categories: programming
tags: [D, dlang, programming, learning, metaprogramming, test, koans]
author: Andrea Manzini
date: 2025-05-21
---

## 💡 The problem


Welcome back, it's been quite a long time since my [last ramblings](https://ilmanzo.github.io/post/fileinput-for-d-programming-language/) on the [D Programming Language](https://dlang.org/)!

This post is born from a necessity. An old project of mine, the [D Koans](https://github.com/ilmanzo/DLangKoans), was using an external library to simplify unit testing, which is more or less the core of the whole project. Unfortunately, the library started giving [some deprecation warnings](https://github.com/linkrope/dunit/issues/36) when compiled with recent D versions.

Since the D Language already has an internal [unit testing framework](https://dlang.org/spec/unittest.html), I thought it would be nice to remove the single dependency and rely only on the standard library. Initially, with some global search/replace, I managed to convert all the tests to `unittest` blocks.

![dlang_meme](/img/dlang_explain_meme.jpg)

## 😫 Stack traces are ugly

Running these tests presented another challenge. Using the standard unit testing directly would confront users with dense error messages, such as:

```
core.exception.AssertError@koans/alias_this.d(39): unittest failure
----------------
??:? _d_unittestp [0x4bb84d]
koans/alias_this.d:39 void koans.alias_this.__unittest_L34_C1() [0x48b731]
??:? void koans.alias_this.__modtest() [0x48b788]
??:? int core.runtime.runModuleUnitTests().__foreachbody_L603_C5(object.ModuleInfo*) [0x4ccdb2]
??:? int object.ModuleInfo.opApply(scope int delegate(object.ModuleInfo*)).__lambda_L2467_C13(immutable(object.ModuleInfo*)) [0x4b2867]
??:? int rt.minfo.moduleinfos_apply(scope int delegate(immutable(object.ModuleInfo*))).__foreachbody_L582_C5(ref rt.sections_elf_shared.DSO) [0x4c1dc7]
??:? int rt.sections_elf_shared.DSO.opApply(scope int delegate(ref rt.sections_elf_shared.DSO)) [0x4c2149]
??:? int rt.minfo.moduleinfos_apply(scope int delegate(immutable(object.ModuleInfo*))) [0x4c1d55]
??:? int object.ModuleInfo.opApply(scope int delegate(object.ModuleInfo*)) [0x4b2839]
??:? runModuleUnitTests [0x4ccbe7]
??:? void rt.dmain2._d_run_main2(char[][], ulong, extern (C) int function(char[][])*).runAll() [0x4c00dc]
??:? void rt.dmain2._d_run_main2(char[][], ulong, extern (C) int function(char[][])*).tryExec(scope void delegate()) [0x4c0069]
??:? _d_run_main2 [0x4bffd2]
??:? _d_run_main [0x4bfdbb]
/usr/include/dlang/dmd/core/internal/entrypoint.d:29 main [0x484a69]
??:? [0x7f94bda2b12d]
??:? __libc_start_main [0x7f94bda2b1f8]
<unknown dir>/<unknown file>:115 _start [0x484884]
core.exception.AssertError@koans/arrays.d(8): unittest failure
```

which is less than ideal for a newbie; also all the unit tests run in parallel so you'd get a wall of weird text. 

## 🦸 Metaprogramming to the rescue

The solution is to *collect* all the unit tests and run them manually in a `foreach` loop!
This leads to another problem: the project is composed of many modules, similar to progressive *"exercises"* that the student must complete to learn. How do we enumerate all the modules, in a somewhat defined order, and make sure the main program imports them, and ensure the main program can import and call their functions? Let me introduce **metaprogramming** :)

Since all the exercises are in a directory, it's easy to group them in a single [`package module`](https://dlang.org/spec/module.html#package-module) 

```bash
$ tree   
.
├── dscanner.ini
├── dub.json
├── koans
│   ├── alias_this.d
│   ├── arrays.d
│   ├── associative_arrays.d
│   ├── basics.d
│   ├── bitwise_operators.d
│   ├── chars.d
│   ├── c_interop.d
│   ├── classes.d
│   ├── concurrency.d
│   ├── ctfe.d
│   ├── delegates.d
│   ├── enums.d
│   ├── exceptions.d
│   ├── files.d
│   ├── foreach_loop.d
│   ├── function_parameters.d
│   ├── helpers.d
│   ├── lambda_syntax.d
│   ├── mixins.d
│   ├── numbers.d
│   ├── operator_overloading.d
│   ├── package.d  <--------------- THIS
│   ├── pointers.d
│   ├── properties.d
│   ├── strings.d
│   ├── structs.d
│   ├── templates.d
│   ├── traits.d
│   ├── tuples.d
│   └── unions.d
├── learn.d
├── README.md
└── scripts
    ├── runner_linux.sh
    └── runner_osx.sh
```

our `package.d` is simple:

{{< highlight D "linenos=true">}}
// koans/package.d 
module koans;

static immutable koansModules = [
    "basics", "numbers", "chars", "strings",
    // ... enumerate all the exercises modules
];

static foreach (m; koansModules)
    mixin("public static import koans." ~ m ~ ";");
{{</ highlight >}}

instead of importing all the modules, we use a loop to create *at compile time* the import statements. In this way, the main program only needs to `import koans` as a whole package.

note: we will reuse the same list of modules in the `main` program:

## ⚙️ A custom test runner

{{< highlight D "linenos=true">}}
// learn.d
module learn;

import core.runtime;
import std.stdio;
import koans;
static import core.exception;

shared static this()
{
    // Override the default unit test runner to do nothing. 
    // After that, "main" will be called.
    Runtime.moduleUnitTester = { return true; };
}

void main()
{
    writeln("Starting your journey to enlightenment...");
    writeln("You will be asked to fill in the blanks in the koans.");
    writeln("Ensure to run 'dub --build=unittest' to run the tests.");
    static foreach (m; koans.koansModules)
    {
        mixin("static import koans." ~ m ~ ";");
        foreach (t; __traits(getUnitTests, mixin("koans." ~ m)))
        {
            try t();
            catch (core.exception.AssertError e)
            {
                writeln("Meditate more on ", e.file, " at line ", e.line);
                return;
            }
        }
    }
    writeln("You have reached the end of your journey");
}
{{</ highlight >}}

The important parts are:

- line 9-14 : need to override the default Runtime.moduleUnitTester function. This will let our `main` run even when the program is compiled with `--unittest` flag.
- line 21: iterate on each module, reusing the same array of strings previously defined in `package.d`
- line 23: build a scoped import statement with the module name, prefixed by package name (e.g. `koans.basics`)
- line 24: use [traits](https://dlang.org/spec/traits.html) to iterate over all unit tests of that module, calling the unit test (which is wrapped as a function) inside a `try-catch` block in order to capture the AssertError
- line 29: if the unit test fails, give the user instructions on which line of which file needs to change and the program terminates

![dlang](/img/DLang.jpg)
(mandatory AI-generated catchy image)

## ✅ Conclusions

My project now does not depend on any other library, and it will be very simple to add new tests: just follow the language conventions and create a new file with unit tests, then write its name in the proper position of the array.

I hope this practical example of D's capabilities was insightful. More importantly, has it made you curious to learn more about the D programming language itself?

Have you used D's metaprogramming for similar tasks? Feedbacks are welcome!


