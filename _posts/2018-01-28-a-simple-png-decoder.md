---
layout: post
title: "a simple PNG decoder"
description: ""
category: programming
tags: [golang, programming, binary, file, hacking]
---
{% include JB/setup %}

while working with image files, I needed a simple way to analize content of a picture; so I wrote this tool that "walks" inside a PNG file and reports all the chunks seen; this is intended to be expanded with more features in a future.


{% highlight go %}
package main

import (
        "encoding/binary"
        "fmt"
        "io"
        "os"
)

type chunk struct {
        Length    uint32
        ChunkType [4]byte
}

func main() {
        if len(os.Args) != 2 {
                fmt.Printf("Usage: %s filename.png\n", os.Args[0])
                os.Exit(1)
        }
        f, err := os.Open(os.Args[1])
        if err != nil {
                panic(err)
        }
        defer f.Close()
        header := make([]byte, 8)
        _, err = f.Read(header)
        fmt.Printf("header: %v\n", header)
        if err != nil {
                panic(err)
        }
        var data chunk
        var offset int64
        offset = 8
        for {
                err = binary.Read(f, binary.BigEndian, &data)
                if err != nil {
                        if err == io.EOF {
                                break
                        }
                        panic(err)
                }
                fmt.Printf("Offset: %d chunk len=%d, type: %s\n", offset, data.Length, string(data.ChunkType[:4]))
                f.Seek(int64(data.Length+4), io.SeekCurrent)
                offset += int64(data.Length) + 4
        }
}
{% endhighlight %}

usage:

{% highlight bash %}
$ go build
$ ./pngwalker example.png
header: [137 80 78 71 13 10 26 10]
Offset: 8 chunk len=13, type: IHDR
Offset: 25 chunk len=93, type: PLTE
Offset: 122 chunk len=2173, type: IDAT
Offset: 2299 chunk len=0, type: IEND
{% endhighlight %}

