---
layout: post
title: "how to automatically expire mysql records after a fixed amount of time"
description: "how to automatically delete mysql records after an amount of time"
category: programming
tags: [mysql, programming, tutorial, database, english]
---
{% include JB/setup %}

# the issue

we have a database table containing usernames and passwords, but we
want to make them temporary like expiring after a fixed number of days from the
creation. This is typical usage for a wi-fi captive portal with RADIUS
authentication backed on mysql.

# the idea

we store a new field in the table with the timestamp, and run a periodic
"cleaner" job that deletes record older than X days.

we can leverage the [mysql event
scheduler](https://dev.mysql.com/doc/refman/5.7/en/event-scheduler.html) in
order to provide a self-contained solution, indipendent from operating system.

# the implementation

{% highlight SQL %}
alter table radcheck add column ts_create TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE EVENT expireuser
ON SCHEDULE EVERY 12 HOUR
DO
DELETE FROM radcheck 
WHERE TIMESTAMPDIFF(DAY, ts_create , NOW()) > 7
;
{% endhighlight %}

to getit working, make sure you have enabled the event scheduler:

{% highlight SQL %}
SET GLOBAL event_scheduler = ON; 
{% endhighlight %}

or by placing

{% highlight bash %}
event_scheduler=ON
{% endhighlight %}

in your my.cnf, section [mysqld]







