---
layout: post
title: "How much code are you testing ? (2)"
description: "Measuring test coverage on binaries"
categories: [programming, testing]
tags: [testing, tutorial, linux, coverage, e2e, qa, tracing, scripting]
author: Andrea Manzini
date: 2025-03-30
---

## ▶️ Intro 

On the [previous post](https://ilmanzo.github.io/post/measuring-coverage-of-integration-tests/) we started our journey with a very simple scenario, and we used a [nice feature](https://go.dev/blog/integration-test-coverage) of the Go programming language to get a measure of how much % of the target program our test is exercising.

This time I am going to experiment a Proof of Concept about how we can obtain a test code coverage metric estimation for a normal binary program, **without any recompilation.**

In this example we will pretend that our task is to write integration tests for the famous `gzip` program, and try to measure the progresses we are doing about *coverage* of our tests.

![coverage](/img/pexels-emhopper-1359036.jpg)
*Even pets need coverage!* Image credits to: [Em Hopper](https://www.pexels.com/@emhopper/)

## 🧮 How ?

The main idea is 
- get in some way the *complete* list of functions present in the program = N
- record, during test, which of those functions are executed = E

The ratio E/N provides an approximation of test effectiveness, guiding us to areas needing expanded coverage.

We don't want to recompile `gzip` with coverage instrumentation, but in our distro we have the *debug information* of the program. Usually they are provided in separate packages, and the repository is not enabled by default, so first of all let's enable them and install the related packages.
On Tumbleweed:

```bash
$ sudo zypper modifyrepo -e repo-debug 
$ sudo zypper refresh
$ sudo zypper in gzip-debuginfo gzip-debugsource
```

## 👐 Functions all the way down

We can use the `gdb` debugger to have a list of all the functions in a program:

```bash
$ sudo zypper install gdb
$ gdb /usr/bin/gzip
For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from /usr/bin/gzip...
Reading symbols from /usr/lib/debug/usr/bin/gzip.debug...
(gdb) info functions
All defined functions:
File ../sysdeps/x86_64/start.S:
        void _start(void);

File ./lib/stat-time.h:
29:     int openat_safer(int, const char *, int, ...);
30:     int rpl_printf(const char *, ...);
116:    int unzip(int, int);
[... long output omitted ...]
```

That looks promising! 

## ☝️ Write the first test

As we did last time, for simplicity we are going to use the `pytest` framework, but [any other](https://open.qa/) would work. First, let's write a *smoke* test:

```python
# test_gzip.py
import os,re
from subprocess import run

PROGRAM='/usr/bin/gzip'

# program should display help
def test_help(capfd):
    process=run([PROGRAM,'-h'])
    stdout, stderr = capfd.readouterr()     
    assert process.returncode == 0
    assert "Usage:" in stdout 
```

On this test, we spawn a process to simply execute `gzip -h`, expecting some specific output. 
let's run it:

```bash
============================= test session starts ==============================
platform linux -- Python 3.13.2, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/binarycoverage
collected 1 item

test_gzip.py .                                                            [100%]

============================== 1 passed in 0.01s ===============================
```

## 👣 Trace it

Now we can trace which functions have been exercised by wrapping the test run with the powerful [`valgrind`](https://valgrind.org/) tool:

```bash
$ sudo zypper install valgrind
$ valgrind --tool=callgrind --trace-children=yes pytest
```

the execution takes a bit longer and we get some new files which contains tracing data:

```bash
$ ls -l callgrind.out.*
-rw-------. 1 andrea andrea 1944681 Mar 30 17:54 callgrind.out.2771
-rw-------. 1 andrea andrea   82977 Mar 30 17:54 callgrind.out.2816
```

These data files are intended to be processed by [callgrind_annotate](https://valgrind.org/docs/manual/cl-manual.html#cl-manual.callgrind_annotate-options) 
that will output a detailed report with all the functions executed (including those in libraries like `glibc`). 

```
$ callgrind_annotate callgrind.out.2816
--------------------------------------------------------------------------------
Profile data file 'callgrind.out.2816' (creator: callgrind-3.24.0)
--------------------------------------------------------------------------------
I1 cache:
D1 cache:
LL cache:
Timerange: Basic block 0 - 52685
Trigger: Program termination
Profiled target:  /usr/bin/gzip -h (PID 2816, part 1)
Events recorded:  Ir
Events shown:     Ir
Event sort order: Ir
Thresholds:       99
Include dirs:
User annotated:
Auto-annotation:  on

--------------------------------------------------------------------------------
Ir
--------------------------------------------------------------------------------
246,004 (100.0%)  PROGRAM TOTALS

--------------------------------------------------------------------------------
Ir               file:function
--------------------------------------------------------------------------------
41,382 (16.82%)  /usr/src/debug/glibc-2.41/elf/dl-lookup.c:do_lookup_x [/usr/lib64/ld-linux-x86-64.so.2]
40,596 (16.50%)  /usr/src/debug/glibc-2.41/elf/dl-reloc.c:_dl_relocate_object_no_relro [/usr/lib64/ld-linux-x86-64.so.2]
17,388 ( 7.07%)  /usr/src/debug/glibc-2.41/elf/dl-lookup.c:_dl_lookup_symbol_x [/usr/lib64/ld-linux-x86-64.so.2]
13,781 ( 5.60%)  /usr/src/debug/glibc-2.41/elf/dl-tunables.c:__GI___tunables_init [/usr/lib64/ld-linux-x86-64.so.2]
13,309 ( 5.41%)  /usr/src/debug/glibc-2.41/elf/../sysdeps/generic/dl-new-hash.h:_dl_lookup_symbol_x
11,941 ( 4.85%)  /usr/src/debug/glibc-2.41/string/../sysdeps/x86_64/multiarch/../multiarch/strcmp-sse2.S:strcmp [/usr/lib64/ld-linux-x86-64.so.2]
 9,951 ( 4.05%)  /usr/src/debug/glibc-2.41/elf/dl-lookup.c:check_match [/usr/lib64/ld-linux-x86-64.so.2]
 8,321 ( 3.38%)  /usr/src/debug/glibc-2.41/elf/do-rel.h:_dl_relocate_object_no_relro
 7,033 ( 2.86%)  /usr/src/debug/gzip-1.13/lib/vasnprintf.c:vasnprintf [/usr/bin/gzip]
 6,968 ( 2.83%)  /usr/src/debug/glibc-2.41/elf/../sysdeps/x86_64/dl-machine.h:_dl_relocate_object_no_relro
 5,935 ( 2.41%)  /usr/src/debug/glibc-2.41/elf/../sysdeps/x86/dl-cacheinfo.h:intel_check_word.constprop.0 [/usr/lib64/ld-linux-x86-64.so.2]
 4,811 ( 1.96%)  /usr/src/debug/glibc-2.41/elf/../bits/stdlib-bsearch.h:intel_check_word.constprop.0
 4,402 ( 1.79%)  /usr/src/debug/glibc-2.41/elf/dl-version.c:_dl_check_map_versions [/usr/lib64/ld-linux-x86-64.so.2]
 4,356 ( 1.77%)  /usr/src/debug/glibc-2.41/elf/dl-tunables.h:__GI___tunables_init
 4,348 ( 1.77%)  /usr/src/debug/gzip-1.13/lib/printf-parse.c:vasnprintf
 2,660 ( 1.08%)  /usr/src/debug/glibc-2.41/stdio-common/vfprintf-internal.c:__printf_buffer [/usr/lib64/libc.so.6]
 2,064 ( 0.84%)  /usr/src/debug/glibc-2.41/stdio-common/Xprintf_buffer_write.c:__printf_buffer_write [/usr/lib64/libc.so.6]
```

While a bit confusing, it contains all the information we need. It just needs some elaboration ...

## 🤖 Automate it

To make our life easier, better use some glue scripting to automate the tools and parse the data with some python code to get the information we need. The complete project [is available on my GitHub repository](https://github.com/ilmanzo/binarycoverage), but here an excerpt of the script `coverage.sh` that runs `pytest` and outputs coverage measure:

```bash
#!/bin/bash
BINARY=gzip
TEMP_DIR=$(mktemp -d)
valgrind --tool=callgrind --trace-children=yes \
  --callgrind-out-file=$TEMP_DIR/callgrind.%p pytest 2> /dev/null
# annotate all the files
for f in $TEMP_DIR/callgrind.* 
do 
  base=$(basename $f)
  # auto annotation with --context=0 can be useful 
  # to have precise source code line execution
  callgrind_annotate --auto=yes --context=0 \
    $f > $TEMP_DIR/"${base#*.}".log 2>/dev/null
done
# dump all the functions in the binary
gdb -ex 'set pagination off' -ex 'info functions' -ex quit \
  $(which $BINARY) > $TEMP_DIR/all_funcs.gdb
python3 analyze.py --binary $BINARY -d $TEMP_DIR
# Clean up: Remove the temporary directory and its contents
rm -rf "$TEMP_DIR"
```

```
> ./coverage.sh
============================= test session starts ==============================
platform linux -- Python 3.13.2, pytest-8.3.4, pluggy-1.5.0
rootdir: /home/andrea/binarycoverage
collected 1 item

test_gzip.py .                                                           [100%]

============================== 1 passed in 0.54s ===============================
--- Binary coverage report ---
Functions coverage: 9/80 11.25%
```

As expected, our "smoke" test on `gzip` runs only 9 functions of 80, with a low 11% coverage.

## 🏃‍➡️ Let's move forward

Now we can improve our testing, as we are driven by the coverage metric. Shall we try the `-V` version option ?

```python
# program should display version information
def test_version(capfd):
    process=run([PROGRAM,'-V'])
    stdout, stderr = capfd.readouterr()
    assert process.returncode == 0
    assert "This is free software" in stdout 
    assert re.search(r"gzip \d.\d\d", stdout)
```

```
$ ./coverage.sh
============================= test session starts ==============================
collected 2 items

test_gzip.py ..                                                          [100%]

============================== 2 passed in 1.17s ===============================
--- Binary coverage report ---
Functions coverage: 10/80 12.50%
```

A bit better! Let's add a negative test for good measure:

```python
# program should fail when given a non existing file
def test_compress_non_existent():
    process=run([PROGRAM,'foobar'])
    assert process.returncode==1
```

```
$ ./coverage.sh
============================= test session starts ==============================
collected 3 items

test_gzip.py ...                                                         [100%]

============================== 3 passed in 1.51s ===============================
--- Binary coverage report ---
Functions coverage: 19/80 23.75%
```

We are on a good track. We doubled the coverage, and still we haven't compressed anything...

## 🏋️ Do some actual work

Time to write a test to compress and decompress a file!

```python
SAMPLE_FILE='sample.txt'

# program should compress and de-compress a file
def test_compress_decompress(capfd):
    create_test_file(SAMPLE_FILE)
    with open(SAMPLE_FILE) as file:
        content=file.readlines()
    process=run([PROGRAM,SAMPLE_FILE])
    assert process.returncode == 0
    compressed_file=SAMPLE_FILE+".gz"
    # decompress and read back content
    process=run([PROGRAM,'-d',compressed_file])
    assert process.returncode == 0
    with open(SAMPLE_FILE) as file:
        assert(file.readlines()==content)
    os.remove(SAMPLE_FILE)
```

```
> ./coverage.sh
============================= test session starts ==============================
collected 4 items

test_gzip.py ....                                                        [100%]

============================== 4 passed in 2.30s ===============================
--- Binary coverage report ---
Functions coverage: 52/80 65.00%
```

That's a big progress! Our tests are getting better. Just one more ? Get to the *evil side* and give it a damaged file:

```python
# program should give error on a damaged compressed file
def test_decompress_error(capfd):
    wrong_file='dummy.txt'
    create_test_file(wrong_file)
    wrong_compressed=wrong_file+'.gz'
    process=run([PROGRAM,wrong_file])
    # now damage the compressed file by writing a random byte
    with open(wrong_compressed, "r+b") as file:
        file.seek(32)
        file.write(bytes(0xFF))
    # decompression should fail        
    process=run([PROGRAM,'-d',wrong_compressed])
    stdout, stderr = capfd.readouterr()
    assert process.returncode==1
    assert 'invalid compressed data' in stderr
    os.remove(wrong_file+'.gz')
```

```
$ ./coverage.sh
============================= test session starts ==============================
collected 5 items

test_gzip.py .....                                                       [100%]

============================== 5 passed in 3.02s ===============================
--- Binary coverage report ---
Functions coverage: 54/80 67.50%
```

That's some good number! Can you think of some areas of improvement ?

## 👓 We miss something

If you use the `-v` verbose option, the python `analyzer` script will output the functions which are tested and which aren't:

```
Executed functions: atdir_eq,atdir_set,bi_windup,build_tree,compress_block,ct_tally,discard_input_bytes,do_exit,fd_safer,file_read,fill_inbuf,fill_window,finish_out,finish_up_gzip,flush_block,flush_outbuf,flush_window,gen_codes,get_input_size_and_time,get_method,get_suffix,huft_build,huft_free,inflate_codes,inflate_dynamic,init_block,input_eof,last_component,license,longest_match,main,open_and_stat,open_safer,openat_safer,pqdownheap,progerror,read_buffer,remove_output_file,rpl_fclose,rpl_fflush,rpl_fprintf,rpl_printf,rpl_vfprintf,scan_tree,send_bits,send_tree,strlwr,treat_file,unzip,updcrc,vasnprintf,write_buf,xstrdup,zip

Missing functions : _start,abort_gzip_signal,copy,copy_block,direntry_cmp_name,display_ratio,do_list,fillbuf,fprint_off,gzip_error,inflate_fixed,make_table,mbszero,read_byte,read_error,read_pt_len,rpl_fcntl,rsync_roll,treat_stdin,try_help,unlzh,unlzw,unpack,write_error,xalloc_die,xpalloc
```

In this way, we have also some *hints* about which features of the program we aren't testing. In this example, among others we can cite the `rsync` compatibility and support for `.Z` files. Of course, some (like the signal handling routines) are very difficult to properly test. 

## 🧵 Final words

It's crucial to remember that the coverage percentage obtained using this method is an approximation. `valgrind` tracks function calls, not individual line or branch executions. Therefore, a function might be called but not fully tested, leading to potential false positives. Additionally, functions indirectly exercised by other calls might not be explicitly listed, resulting in false negatives. The performance overhead introduced by `valgrind` also means this technique is more suitable for offline analysis than real-time testing.

On the other hand, it has the benefits that it's simple to implement, doesn't require big effort nor special setup and you can use it as an indication if the integration tests you are writing are improving over the time or not. Another good use can be to detect when the new version of the programs have more features, as your coverage will get lower with the update would mean you are not testing the new stuff.

Thanks for following me until the end of this long post, feel free to send comments and feedback, happy hacking! :wave:
