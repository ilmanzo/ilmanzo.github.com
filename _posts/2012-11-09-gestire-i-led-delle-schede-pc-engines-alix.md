---
layout: post
title: "gestire i led delle schede PC Engines ALIX in Ruby"
description: ""
category: hacking
tags: [linux, embedded, debian, ruby]
---
{% include JB/setup %}

Natale si avvicina: mentre smanettavo su queste ottime [PC Engines ALIX](http://pcengines.ch/alix.htm) su cui ho installato una [Debian modificata](http://code.google.com/p/debian-for-alix/),
ho scritto una comoda interfaccia per accendere/spegnere e far lampeggiare i led alla velocità desiderata...

{% highlight ruby %}
class Led
  #numero da 1 a 3
  def initialize(ledno)
    ledno++ # passo 0 ma comando 1
    ledno=1 if ledno<1
    ledno=3 if ledno>3
    @ledsyspath="/sys/devices/platform/leds_alix2/leds/alix:#{ledno}/"
  end
  def blink(millisec)
    File.open(@ledsyspath+'trigger','w') { |f| f.write('timer') }
    File.open(@ledsyspath+'delay_off','w') do |f|
      f.write(millisec.to_s)
    end
    File.open(@ledsyspath+'delay_on','w') do |f|
      f.write(millisec.to_s)
    end
  end
  def blink_slow!
    blink(500)
  end
  def blink_fast!
    blink(50)
  end
  def on!
    File.open(@ledsyspath+'trigger','w') { |f| f.write('default-on') }
    File.open(@ledsyspath+'brightness','w') do |f|
      f.write('1')
    end
  end
  def off!
    File.open(@ledsyspath+'trigger','w') { |f| f.write("none") }
    File.open(@ledsyspath+'brightness','w') do |f|
      f.write('0')
    end
  end
end 
{% endhighlight %}
