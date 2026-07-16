---
layout: post
title: "Embed git commit hash into an executable"
description: "How to insert the current HEAD commit hash in a binary"
categories: programming
tags: [programming, 'crystal lang', crystal, git, macros, comptime, nim, 'nim lang']
author: Andrea Manzini
date: 2023-07-01
---

## The problem

When we write our programs or libraries, usually we ship to the end user a packaged binary. 
If a user wants to report a bug or ask for a feature, one of the most important information to have is *"which version of the software are you using ?"*

Since as any good programmer you likely use a source code control system, you should not rely only on the numeric version, but it's practical to include also the **git commit hash** of the software you are actually shipping.

Including the Git commit hash into an executable program can be a helpful practice in various scenarios, especially during the development and deployment process. The Git commit hash is a unique identifier for a specific version of the source code, and it offers several advantages:

- **Version Identification**: The Git commit hash uniquely identifies a specific version of the source code. By embedding it in the executable, you can easily determine which exact version of the code was used to build the executable. This is useful for tracking issues, debugging, and providing accurate information to support teams.

- **Reproducibility**: When an issue or bug arises in the deployed executable, having the Git commit hash helps in reproducing the problem. With the exact source code version, developers can check out the codebase to the same state, ensuring consistent behavior for debugging and fixing the issue.

- **Auditing and Compliance**: In certain industries or projects, it's essential to maintain strict control over the code used in production. Including the Git commit hash provides an audit trail, helping to ensure compliance with specific requirements or regulations.

- **Continuous Integration and Continuous Deployment (CI/CD)**: In CI/CD pipelines, it's crucial to maintain a clear association between the deployed executable and the source code version. The Git commit hash enables better tracking and management of the pipeline's flow.

- **Collaboration and Communication**: When developers collaborate on a project, sharing executables built from specific Git commit hashes ensures that everyone is using the same version of the code. This consistency helps in debugging and ensures that everyone is working on a common base.

- **Rollbacks and Hotfixes**: In case an issue is discovered in the deployed version of the executable, having the Git commit hash allows for quick rollbacks to a previous stable version or creating hotfixes based on a specific commit.

- **Testing and QA**: By including the Git commit hash in the executable, testers and quality assurance teams can quickly identify the version being tested, making it easier to report bugs and issues accurately.

Overall, including the Git commit hash in an executable program improves traceability, accountability, and collaboration throughout the development and deployment lifecycle, making it an important best practice for software development teams. While it's a mostly documented practice for [mainstream languages](https://developers.redhat.com/articles/2022/11/14/3-ways-embed-commit-hash-go-programs), I'd like to show and promote solutions also on other languages.


## Crystal Solution

In [Crystal](https://crystal-lang.org/) this is rather easy to achieve, thanks to [compile time macros](https://crystal-lang.org/reference/1.8/syntax_and_semantics/macros/index.html):

{{< highlight crystal >}}

VERSION   = "0.1.0"
GITCOMMIT = {{ `git rev-parse --short HEAD`.stringify.strip }}
puts "This is MyProgram v#{VERSION} [##{GITCOMMIT}]"

{{</ highlight >}}

What's happening ? Basically during compilation the command inside the backticks is being executed by the compiler, and output is inserted into a string variable. So convenient!
So let's built and check : 

{{< highlight bash >}}
$ shards build
Dependencies are satisfied
Building: myprogram

$ bin/myprogram
This is MyProgram v0.1.0 [#cfd90a9]
{{</ highlight >}}

To have an evidence, it's easy to inspect the actual binary and find the string embedded:

{{< highlight bash >}}
$ strings bin/myprogram | grep MyProgram
This is MyProgram v0.1.0 [#cfd90a9]
{{</ highlight >}}

## Nim Solution

Also [Nim](https://nim-lang.org/) Language has powerful [compile time evaluation](https://castillodel.github.io/compile-time-evaluation/) features:

{{< highlight nim >}}

# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import std/strformat

proc getCommitHash(): auto =
  staticExec("git rev-parse --short HEAD")

const
  gitCommitHash: string = getCommitHash()
  programVersion: string = "0.1.0"

when isMainModule:
  echo fmt"This is MyProgram v{programVersion}#[{gitCommitHash}]"

{{</ highlight >}}

let's build and try out:

{{< highlight bash >}}
$ nimble build -d:release --opt:size 
  Verifying dependencies for myprogram@0.1.0
   Building myprogram/myprogram using c backend

$ ll
total 112
drwxr-xr-x 1 andrea andrea     64 Jul  1 11:38 ./
drwxr-xr-x 1 andrea andrea   1186 Jul  1 11:09 ../
drwxr-xr-x 1 andrea andrea    144 Jul  1 11:31 .git/
-rwxr-xr-x 1 andrea andrea  39104 Jul  1 11:38 myprogram*
-rw-r--r-- 1 andrea andrea    233 Jul  1 11:09 myprogram.nimble
drwxr-xr-x 1 andrea andrea     26 Jul  1 11:09 src/

$ ./myprogram
This is MyProgram v0.1.0 [#3416678]

{{</ highlight >}}

If you are interested in the topic, be sure to check out also [Andre von Houck](https://github.com/treeform) excellent fosdem talk: [Nim Metaprogramming in the real world](https://archive.fosdem.org/2022/schedule/event/nim_metaprogramming/)