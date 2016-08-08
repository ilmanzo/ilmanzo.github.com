---
layout: post
title: "wrapping c plus plus classes in Python"
description: ""
category: 
tags: []
---
{% include JB/setup %}

This is a quick and dirty way to interface C++ code with Python, translating one or more C++ classes in Python objects.

First, we need some c++ sample code:

{% highlight c++ %}
//myclass.h
#ifndef MYCLASS_H
#define MYCLASS_H

#include <string>

using namespace std;

namespace pets {
    class Dog {
    public:
        Dog(string name, int age);
        virtual ~Dog();
        string talk();
    protected:
        string m_name;
        int m_age;
    };
}
{% endhighlight %}

{% highlight c++ %}
//myclass.cpp
#include "myclass.h"

#include <string>

namespace pets {

    Dog::Dog(std::string name, int age): 
     m_name(name),m_age(age) { }

    Dog::~Dog() { }

    std::string Dog::talk() {
        return "BARK! I am a DOG and my name is "+m_name;
    }
}
{% endhighlight %}

now, we can try a little test program just to exercise our class:

{% highlight c++ %}
#include <iostream>

#include "myclass.h"

using namespace std;

int main()
{
	pets::Dog dog("Charlie",3);
	
	cout << dog.talk() << endl;
}
{% endhighlight %}

compile and run:

{% highlight bash %}
g++ myprog.cpp myclass.cpp -o myprog  ; ./myprog
{% endhighlight %}

To use this code from Python, we need to create a **wrapper** using [Cython](http://cython.org/). 

Cython is a programming language that makes writing C extensions for the Python language as easy as Python itself. It aims to become a superset of the Python language which gives it high-level, object-oriented, functional, and dynamic programming. Its main feature on top of these is support for optional static type declarations as part of the language. The source code gets translated into optimized C/C++ code and compiled as Python extension modules. This allows for both very fast program execution and tight integration with external C libraries, while keeping up the high programmer productivity for which the Python language is well known.

So this is the "C++ to python" wrapper glue code:


```
#pets.pyx
from libcpp.string cimport string

cdef extern from "myclass.h" namespace "pets":
  cppclass Dog:
    Dog(string, int)
    string talk()

cdef class PyDog:
  cdef Dog* c_dog #Cython class holds a c++ "Dog" instance
  def __cinit__(self, string name, int age):
    pyname=<bytes>name
    self.c_dog=new Dog(pyname,age)
  def __dealloc__(self):
    del self.c_dog
  def talk(self):
    return self.c_dog.talk()

```

we can also write a setup script to create an easy and smooth compilation/install process:

{% highlight python %}
#setup.py
from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

extensions = [
    Extension("pets", ["pets.pyx","myclass.cpp"], language="c++"),
]

setup(
  name = 'test_pets',
  ext_modules = cythonize(extensions)
)
{% endhighlight %}

using this, to compile all the code in a single shared library, we run:

{% highlight bash %}
python3 setup.py build_ext --inplace
{% endhighlight %}

After this step, we have under current directory a new file with a .so extension, and we can finally use this shared library as a Python module:

{% highlight python %}
import pets

dog1=pets.PyDog(b"Max",5)

print(dog1.talk())
{% endhighlight %}

notice that under the hood a lot of "automagic" type conversions does happen; Cython for example is able to translate between standard C++ enumerable classes and Python tuples. More information of course is available in the [official documentation](http://cython.readthedocs.io/en/latest/index.html)
