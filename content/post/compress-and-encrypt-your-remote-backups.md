+++
author = "Andrea Manzini"
title = "Compress and encrypt your backups"
date = "2014-06-11"
description = "How to securely backup your files in a remote location"
tags = [
    "linux",
    "backup",
    "tips",
    "storage",
    "sysadmin"
]
categories = [
    "sysadmin"
]
+++


It's always recommended to backup your data for safety, but for safety AND
security let's encrypt your backups!


to compress and encrypt with 'mypassword':
{{< highlight bash >}}
tar -Jcf - directory | openssl aes-256-cbc -salt -k mypassword -out backup.tar.xz.aes
{{</ highlight >}}

to decrypt and decompress:
{{< highlight bash >}}
openssl aes-256-cbc -d -salt -k mypassword -in backup.tar.xz.aes | tar -xJ -f - 
{{</ highlight >}}

Another trick with the tar command is useful for remote backups:
{{< highlight bash >}}
tar -zcvfp - /wwwdata | ssh root@remote.server.com "cat > /backup/wwwdata.tar.gz"
{{</ highlight >}}




