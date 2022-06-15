---
layout: post
title: "automate OTP credentials for multi-factor authentication"
description: "automate generation of OTP for multi-factor authentication"
categories: automation
tags: [bash, linux, hacking, otp]
author: Andrea Manzini
date: 2022-06-14
---

## Background:

I work with one or more terminal command-line always opened and having to pick up my phone to generate an OTP breaks my flow; also it's always nice to have an alternate source of multi-factor authentication if something bad happens, one day you could lose or break your trusty mobile device.

Therefore I was looking for a way to login through [Okta](https://www.okta.com/) portals *without* a phone. 
You may argument that this defeats the whole meaning of MFA, but let's say *it's only an hack for research and fun purpose* ...

## DISCLAIMER:

This setup should be used only on ANOTHER trusted device, so use it at your own risk, and be sure to always properly protect your credentials: security is a very serious topic.

## TLDR:

With this setup, every time you write ```:okta``` in any text entry field, it will be replaced with a properly generated OTP!

![okta_otp](/img/okta_otp.gif)

## Requirements:
Install [pass-otp](https://github.com/tadfisher/pass-otp#installation).

for openSUSE Tumbleweed users like me, it's just a matter of

    # zypper install pass-otp


## Steps:
If you already have multifactor authentication set up, start with step 1.

Otherwise, login up to the point where it asks you to "Set up
(two-|multi)factor authentication", and go to step 4.

1. Login to your organisation's Okta settings. The url is typically of the
   form `https://OKTA_HOME_PAGE/enduser/settings`.


For example,

- The University of Sydney: https://sso.sydney.edu.au/enduser/settings
- Garvan: https://garvan.okta.com/enduser/settings
- Linkedin: https://linkedin.okta.com/enduser/settings
- Docusign: https://docusign.okta.com/enduser/settings
- Groupon: https://groupon.okta.com//enduser/settings


2. Scroll to "Extra Verification". This is typically at the bottom on the
   right.

3. If you already have Okta Verify or Google Authenticator set up with your
   organisation, remove it.

4. Now you need to retrieve the secret one-time password (OTP) key.

    1. Click "Set up" next to "Okta Verify".

    2. If a button appears, click it. It may say "Configure factor" or "Set
       up".

    3. Click "iPhone" or "Android". It doesn't matter which one you pick, you
       won't be needing a phone.

    4. Click "Next".

    5. Click "Can't scan?".

    6. Click the first dropdown menu and select "Setup manually without push
       notification".

    7. Copy the secret key to your clipboard.

5. Create the OTP generator by running the following command, replacing
   `OTP_NAME` with a name of your choosing. Paste the secret key when prompted.
```sh
$ pass otp insert -esi byebyeokta OTP_NAME
```

6. Generate the OTP by running the following command.
```sh
$ pass otp OTP_NAME
```
Copy the output. Alternatively, use the `-c` option to copy it directly.
```sh
$ pass otp -c OTP_NAME
```

7. Enter the OTP.

    1. Click "Next".

    2. Paste the number in the "Enter Code" text box.

    3. Click "Verify" to finish the setup.

    4. You may have to click "Finish" as well.

8. Now, whenever you are required to enter the OTP code in the future, simply
   generate it by following step 6.


## Authenticator App
Add the secret key to a OTP authenticator app. This is useful if you need to
use a different computer and don't have access to one which you set up
`pass-otp` with.

1. Find a way to add a new account by entering the secret key manually into the
   app. For the Okta Verify app, do the following. The steps are similar for
   the Google Authenticator app.

    1. Press the "+" button in the top-right corner.

    2. Press "Other".

    3. Press "Enter Key Manually".

    4. Type an Account Name of your choosing.

    5. Type in the secret key. If you have lost the key, run the following
       command to retrieve it.
    ```sh
    $ pass OTP_NAME | awk -F '[=&]' '{print $2}'
    ```

    6. Press "Done".

2. Confirm you get the same codes on your phone as when following step 6. If
   not, you may have misspelled the secret key, in which case try again.

3. If you have an old account on a OTP authenticator app which you removed in
   step 3 you can remove it from the app.


## Automating
The goal is to auto fill and submit once prompted to enter the OTP code.

The [original author](https://github.com/sashajenner) used [qutebrowser](https://github.com/qutebrowser/qutebrowser), binding a key chain to a `submit_otp_qute.sh`
userscript; so you can follow that 

For other purposes, and many reasons, personally I'm already using a tool like [Espanso](https://espanso.org/), but also [AutoKey](https://github.com/autokey/autokey) and any other "text-expander" that is able run external commands can meet the requirements. 

You can use an Espanso configuration snippet like this:

{{< highlight yaml >}}
- trigger: ":okta"
  replace: "{{output}}"
  vars:
    - name: output
      type: shell
      params:
        cmd: /usr/local/bin/submit_otp.sh OTP_NAME
{{</ highlight >}}

be sure to replace ```OTP_NAME``` with the one you chose before.

The script executed is quite easy, simply retrieve the code and echoes to stdout:

{{< highlight bash >}}
#!/bin/sh
# user script that enters the otp code 
# designed to be used when prompted with the Okta Verify "Enter Code" form
if [ "$#" -ne 1 ]; then
	echo "usage: $0 OTP_NAME"
	exit 1
fi

OTP_NAME="$1"

# retrieve the otp
otp=$(pass otp "$OTP_NAME")

if [ -z "$otp" ]; then
	echo "Unknown OTP_NAME '$OTP_NAME'"
	exit 1
fi

# insert the otp at the focussed text box and submit it
echo "$otp"
{{</ highlight >}}


![okta_otp](/img/okta_otp.gif)

have fun,


## Credits

Kudos to [Sasha](https://github.com/sashajenner) for most of detailed instructions


