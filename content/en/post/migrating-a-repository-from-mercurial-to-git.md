---
layout: post
title: "migrating a repository from mercurial to git"
description: ""
categories: 
tags: [scripting, linux, programming, tips, git, mercurial]
author: Andrea Manzini
date: 2019-12-15
---


Since [bitbucket is sunsetting the support for mercurial repositories](https://bitbucket.org/blog/sunsetting-mercurial-support-in-bitbucket), I wrote a quick and dirty script to automate the migration from mercurial to GIT:

{{< highlight bash >}}
#!/bin/bash
set -e
set -u

if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters"
    echo "usage: migrate.sh reponame hgrepourl gitrepourl"
    exit 1
fi

REPONAME=$1
HGURL=$2
GITURL=$3

echo "Migrating $REPONAME from $HGURL to $GITURL..."

cd /tmp
hg clone $HGURL
cd $REPONAME
hg bookmark -r default master
hg bookmarks hg
cd ..
mv $REPONAME ${REPONAME}_hg
mkdir ${REPONAME}_git
cd ${REPONAME}_git
git init --bare .
cd ../${REPONAME}_hg
hg push ../${REPONAME}_git
cd ../${REPONAME}_git
git remote add hgmigrate $GITURL
git push hgmigrate master
cd /tmp
rm -rf /tmp/${REPONAME}_hg /tmp/${REPONAME}_git
echo "...done"
{{</ highlight >}}

Before running the script, you only need to install git and create a git repository (remote or local). 





