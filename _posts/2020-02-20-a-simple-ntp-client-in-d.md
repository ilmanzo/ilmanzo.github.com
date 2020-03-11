---
layout: post
title: "a very simple NTP client in D"
description: ""
category: [linux, programming]
tags: [linux, programming, D, dlang, network, socket]
---
{% include JB/setup %}

I am quite a fan of the [D programming language](https://dlang.org/) and I think it deserves more attention, even if since a few months it's becoming more and more popular, as it gained top20 in the [TIOBE Index](https://www.tiobe.com/tiobe-index/) for February 2020.

As an experiment in network programming, I took [this simple NTP client](https://github.com/SanketDG/c-projects/blob/master/ntp-client.c) written in C and translated to D ; in my opinion while it's keeping the low-level nature, it's shorter, clearer and more effective. It's only a dozen lines of code, but full program is available [on my github](https://github.com/ilmanzo/ntpclient); stars and contributions are welcome!

Starting from the top, we find the needed imports and then the packet structure, as is specified in the reference implementation (it's a matter of copy-paste). Notice that in D we can initialize the structure field with tne value we need.

{% highlight d %}

import std.stdio;
import std.socket;
import std.datetime;
import std.bitmanip;

// from reference
struct Packet {
    align(1):             // we want the structure packed, with no gaps
    byte flags=0x23;  // Flags 00|100|011 for li=0, vn=4, mode=3
    byte stratum;
    byte poll;
    byte precision;
    uint root_delay;
    uint root_dispersion;
    uint referenceID;
    uint ref_ts_secs;
    uint ref_ts_frac;
    uint origin_ts_secs;
    uint origin_ts_frac;
    ubyte[4] recv_ts_secs;  // This is what we need mostly to get current time.
    ubyte[4] recv_ts_fracs; // for this example nanoseconds can be dropped
    uint transmit_ts_secs;
    uint transmit_ts_frac;
}

{% endhighlight %}

when the **main** function begins, we create a new UDP socket, with protocol IPV4, and allocate on the stack. Then we tell the socket to connect to a NTP server of the 'europe' pool. Of course you can change it to any address you prefer :)

{% highlight d %}
const ntpEpochOffset = 2208988800L; // Difference between Jan 1, 1900 and Jan 1, 1970

void main()
{
    auto sock=new UdpSocket(AddressFamily.INET);
    Packet packet;  // stack allocation
    sock.connect(new InternetAddress("europe.pool.ntp.org",123));
{% endhighlight %}

Here it comes the trickiest part: the *send* method of the [UdpSocket class](https://dlang.org/library/std/socket/udp_socket.html) requires a slice, and returns the number of bytes effectively transferred; but we have to send a struct, so we need to cast our *packet* as a 1-element slice:

{% highlight d %}
const sent=sock.send((&packet)[0..1]);
const received=sock.receive((&packet)[0..1]);
if (sent!=Packet.sizeof || received!=Packet.sizeof) {
    writeln("Hmmm .. Something went wrong");
}
{% endhighlight %}

The last piece is straightforward, thanks also to [Phobos, the powerful D standard library](https://dlang.org/phobos/): we convert the received bytes to our native bit-order representation (notice the template syntax) and translate from unix Epoch to human-readable date and time. Every variable type is inferred automagically for us :)


{% highlight d %}
sock.close();
// network byte order is Big-Endian
auto unixTime=bigEndianToNative!uint(packet.recv_ts_secs); 
// NTP returns seconds from Jan 1, 1900
auto stdTime = SysTime.fromUnixTime(unixTime-ntpEpochOffset); 
writeln("Hello, the time is: ",stdTime);
{% endhighlight %}



