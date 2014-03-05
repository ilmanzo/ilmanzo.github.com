---
layout: post
title: "dovecot: cleaning old Spam and Trash messages after some days"
description: "a script to do maintenance of a small number of mail folders"
category: sysadmin 
tags: [dovecot, linux, sysadmin, mail, postfix]
---
{% include JB/setup %}

This script is useful to delete old messages in "Junk" mail folders (Spam, Trash) automatically after some days.

[adapted from these notes](http://notes.sagredo.eu/it/node/123) to work on debian/postfixadmin/dovecot

{% highlight bash %}
#!/bin/bash
#
# itera sulle mailbox cancellando messaggi vecchi
# per default, nel cestino 30gg e Spam 15 gg
#

# MySQL details
HOST="127.0.0.1";
USER="put_here_your_mysql_user";
PWD="put_here_your_mysql_password";
MYSQL="/usr/bin/mysql";
# dovecot details
DOVEADM="/usr/bin/doveadm";

TEMPFILE=$(/bin/mktemp)

# Output sql to a file that we want to run
echo "use postfixadmin; select username from mailbox" > $TEMPFILE

# Run the query and get the results (adjust the path to mysql)
results=$($MYSQL -h $HOST -u $USER -p$PWD -N < $TEMPFILE);

# Loop through each row
for row in $results
        do
        echo "Purging $row Trash and Junk mailbox..."
        # Purge expired Trash
        $DOVEADM -v expunge mailbox Trash -u $row savedbefore 30d
        # Purge expired Spam
        $DOVEADM -v expunge mailbox Spam -u $row savedbefore 15d
done

rm $TEMPFILE

{% endhighlight %}

