---
layout: post
title: "Hijack C library functions in D"
description: ""
category: [linux, programming]
tags: [linux, programming, shared lib, D, dlang, hacking]
---
{% include JB/setup %}

I like playing with the [D programming language](https://dlang.org/) and I wrote this little post to show how it's easy to create a dynamic library (shared object, `.so`) that can be invoked in other programs; to have a little fun we will write a D replacement for the `rand()` C standard library function call. For your convenience, all the code is also [on github](https://github.com/ilmanzo/hijack_C_stdlib_func_with_D)

Let's start with the demo implementation, a C program that calls 10 times the stdlib function `rand()` to get a random number.

{% highlight c %}
// random_num.c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
 
int main(){
  srand(time(NULL));
  int i = 10;
  while(i--) printf("%d\n",rand()%100);
  return 0;
}
{% endhighlight %}

if we compile and run this program, we get something like this:

{% highlight bash %}
$ gcc -O3 -ansi -pedantic -std=c99 -Wall -O2 random_num.c -o random_num
$ ./random_num 
79
51
80
49
24
63
95
85
96
97
{% endhighlight %}

Now we will play a little and leverage **`LD_PRELOAD`** to give our program an 'alternate' version of `rand()` ; this new one will be written in D:

{% highlight d %}
//file: mylib.d
module mylib;

import std.conv;
import std.file : readText;
import std.string : chomp;

export extern(C) int rand() {
      return readText("random.txt").chomp.to!int;
}
{% endhighlight %}

as you can see, after the imports we declare a `rand()` function with C linkage; this function doesn't accept any parameter but needs to return an integer. So we can use advanced **phobos** functions in [the powerful D standard library](https://dlang.org/phobos/index.html), together with an easy to read [UFCS syntax](https://en.wikipedia.org/wiki/Uniform_Function_Call_Syntax) to read a number from a text file, remove extra whitespaces and convert to an integer. As a result, any program that uses the `rand()` function will get the number stored in the text file. Easier than Python, native as C.

Let's try:


{% highlight bash %}
$ echo 42 > random.txt
$ dmd -m64 -fPIC -w -O -shared -of=mylib.so mylib.d
$ LD_PRELOAD=./mylib.so ./random_num 
42
42
42
42
42
42
42
42
42
42
{% endhighlight %}

As a bonus, I leave here the GNUMakefile used for compilation and test of both programs; I prefer GNU Make format because it doesn't rely on explicit "TAB" characters so it's easier to copy and paste.

{% highlight make %}
#file: GNUMakefile
.RECIPEPREFIX +=

.PHONY: all

CFLAGS = -ansi -pedantic -std=c99 -Wall -O2
DFLAGS = -m64 -fPIC -w -O -shared

all: random_num mylib.so

random_num: random_num.c
  gcc -O3 $(CFLAGS) $< -o $@

%.so:%.d
  dmd $(DFLAGS) -of=$@ $<

clean:
  rm -f *.so *.o random_num

real_random: all
  ./random_num

fake_random: all
  LD_PRELOAD=./mylib.so ./random_num

{% endhighlight %}
