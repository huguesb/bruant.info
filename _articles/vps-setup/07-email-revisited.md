---
name: Email revisited
---

SMTP is a venerable protocol but in its vanilla form it is ridiculously vulnerable
to snooping and spoofing. This section is a modest attempt to mitigate these
issues.

### DKIM

[DKIM](http://en.wikipedia.org/wiki/DomainKeys_Identified_Mail) is a way to sign
messages to prove to the recipient that the SMTP server they originate from is
legitimately associated with the domain of the sender.

{%highlight bash%}
apt-get install opendkim opendkim-tools
opendkim-genkey -t -s mail -d bruant.info
mv mail.private /etc/mail/dkim.key
{%endhighlight%}

Beside the private key, a file named `mail.txt` will be generated. It's meant to
be added to a special TXT record in your zone file, for instance mine looks like:

{%highlight text%}
mail._domainkey 10800 IN TXT "v=DKIM1; k=rsa; t=y; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDWAWDQQG9LCd5mC1fG0ZBqviZ4TSF25BqOkJS/I3rHQ4eXp1hgQnaJhanW+I9F2k+u0wBTVKtFbwsrAO71QTtxjHPoZ8p1o6/ooYOU6NB/KPK3iPqCwf2SyNUgfiOZGvwPn0bBswXLakh13BxgYl99xQWRTKsEbT/X7JOmAh1hYQIDAQAB"
{%endhighlight%}

For DKIM to work you will need reverse-DNS lookup to work. This is usually
configured via the control panel of your VPS provider. Use `dig` to verify the
correct mapping.

{%highlight bash%}
$ dig +nocmd +noquestion +nocomments +nostats -x 46.226.109.60
60.109.226.46.in-addr.arpa. 3104 IN     PTR     bruant.info
{%endhighlight%}

**NOTE** GMail will reject incoming emails when connecting over IPv6
if the (IPv6) reverse DNS is not correctly setup. Either set it or
disable IPv6 completely in postfix (otherwise you'll have random
delivery failure, depending on whether postfix opts for IPv4 or
IPv6 when connecting to GMail servers).

The OpenDKIM config file is `/etc/opendkim.conf` and should look like:

{%highlight text%}
Syslog                  yes
Domain                  bruant.info
KeyFile                 /etc/mail/dkim.key
Selector                mail
AutoRestart             yes
Background              yes
Canonicalization        relaxed/relaxed
LogWhy                  yes
InternalHosts           /etc/mail/InternalHosts
{%endhighlight%}

The associated `/etc/mail/InternalHosts` is as follows:

{%highlight text%}
127.0.0.1
::1
localhost
bruant.info
{%endhighlight%}

Finally we need to configure how OpenDKIM will communicate with postfix.
This is controlled by `/etc/default/opendkim`, which should look like:

{%highlight bash%}
SOCKET="inet:8891@localhost" # listen on loopback on port 8891
{%endhighlight%}

To complete the setup, add the following to `/etc/postfix/main.cf`:

{%highlight text%}
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
{%endhighlight%}

As usual, restart all services whose configuration have changed:
{%highlight text%}
service opendkim restart && service postfix restart
{%endhighlight%}


### SPF

[SPF](http://en.wikipedia.org/wiki/Sender_Policy_Framework) is another way to
prevent spoofing and will reduce the probability for emails sent from your server
to be classified as spam.

Figure out which policy suits your need and edit our zone file accordingly. My
own SPF-related records look like:

{%highlight text%}
@ 10800 IN SPF "v=spf1 a ~all"
@ 10800 IN TXT "v=spf1 a ~all"
{%endhighlight%}

The duplication may not be necessary but better safe than sorry.

**NOTE** GMail documentation warn that strict constraints ("-" as opposed to "~")
may be problematic.

It is also possible to enforce SPF checking on incoming emails. I didn't do it
yet so I cannot describe the process but some kind Ubuntu user made a
[basic guide](https://help.ubuntu.com/community/Postfix/SPF).


### Auto-encrypt

I have a [GPG key](/gpg.asc), unfortunately very few of the people I correspond
with have so much as heard of public key encryption and even those who have are
unwilling to go through the hassle of signing/encrypting emails.

But lo and behold, I stumbled upon a guy describing how he
[encrypts all incoming emails](https://grepular.com/Automatically_Encrypting_all_Incoming_Email).
It's not as good as end-to-end encryption but at least it means emails are
encrypted at rest on the server, a pretty significant step up in a VPS context.

The original guide was for [Exim](http://exim.org) but a kind soul took care of
adapting the process to [work with Dovecot](https://perot.me/encrypt-specific-incoming-emails-using-dovecot-and-sieve).

Using a recent version of Dovecot from a PPA (or built from source) drastically
simplifies the process: the only steps left are configuring Dovecot to find the
sieve script and adding the appropriate public key to the GPG keyring.

I made slight modifications to the sieve script to keep encrypted emails in
the same inbox as other emails and avoid encrypting emails sent from my own
domain. That last filter is a bit blunt and may need to be refined in the future
but for now it's good enough to avoid encrypting the diagnostics emails sent
by local daemon (denyhosts, psad, ...)

My `~/.dovecot.sieve` looks like:
{%highlight text%}
require ["vnd.dovecot.filter"];

if allof(address :matches "To" "hugues@bruant.info",
         not address :matches "From" "*@bruant.info"){
    filter "gpgit" "hugues@bruant.info";
    stop;
}
{%endhighlight%}

