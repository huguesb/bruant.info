---
weight: 5
name: Email server
---
[Dovecot](http://www.dovecot.org/) combination which is known to be fairly efficient,
quite flexible and reasonably easy to configure.

Ubuntu 12.04 comes with an outdated version of Dovecot which was a problem for me
because I wanted to use the latest version of the [Pigeonhole](http://pigeonhole.dovecot.org/)
plugin to script my email server. Thankfully, somebody created a [PPA](https://launchpad.net/~kokelnet/+archive/dovecot22)
with a suitably fresh version.

**NB:** The truly paranoid should not trust a random PPA but build the package from source
instead.

```bash
add-apt-repository ppa:kokelnet/dovecot22
apt-get update
apt-get install postfix dovecot dovecot-pigeonhole
```


The postfix package will ask you a few questions during setup via an ugly ncurses
interface. You can safely ignore them as we'll edit the configuration manually
anyway.


### Certificates

First, let's take care of the certificates we're going to use to encrypt SMTP
and IMAP connections (oh, by the way, I'm not going to bother with POP3 but
it's supported by dovecot and I hear it 's not hard to setup).

```bash
./gencert.sh /etc/ssl/private/smtpd.key /etc/ssl/certs/smtpd.crt
./gencert.sh /etc/ssl/private/dovecot.pem /etc/ssl/certs/dovecot.pem
```

The script will prompt you for some fields of the Distinguished Name of the
certs. Answer carefully, at the very least for the CN field, or your certs
may be rejected by some servers/clients. In particular the CN of the SMTP
cert MUST match your mail domain.


### Dovecot

Dovecot provides a couple of different components of interest to us:

* [SASL](http://en.wikipedia.org/wiki/Simple_Authentication_and_Security_Layer)
  authentication with pluggable backends
* [IMAP](http://en.wikipedia.org/wiki/Internet_Message_Access_Protocol) server
  to access your emails from a remote client (mobile or desktop)
* [LMTP](http://en.wikipedia.org/wiki/Local_Mail_Transfer_Protocol) server that
  sits between Postfix and local maildirs
* [Sieve](http://sieve.info/) interpreter to customize the behavior of said LMTP
  server

First, we need to enable IMAP and LMTP in `/etc/dovecot/dovecot.conf` :
```text
protocols = imap lmtp
```

The second most important config file is `/etc/dovecot/conf.d/10-master.conf`,
where you should adjust LMTP and SASL settings as follows:

```text
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}
service auth {
  unix_listener auth-userdb {
    mode = 0660
  }

  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
```

Then, each component can be configured via it's own config file in `/etc/dovecot/conf.d`.
This document only address the handful I tweaked but it's acceptable (in fact even
recommended) to poke around and adapt the system to your particular needs.


SASL is configured via `/etc/dovecot/10-auth.conf`. Mine looks roughly like this:
```text
disable_plaintext_auth = yes
auth_mechanisms = plain
!include auth-passwdfile.conf.ext
```

The apparent contradiction between the first two lines lies in the fact that
plaintext auth is perfectly acceptable over a TLS connection.

As already mentioned, Dovecot [authentication](http://wiki2.dovecot.org/Authentication)
is pretty versatile. I opted for a simple [passwdfile](http://wiki2.dovecot.org/AuthDatabase/PasswdFile)
but another option may be better for you.


Make sure `/etc/dovecot/10-ssl.conf` points to the key and certificate you generated:

```text
ssl_cert = </etc/ssl/certs/dovecot.pem
ssl_key = </etc/ssl/private/dovecot.pem
```


The location of maildirs is controlled by `/etc/dovecot/10-mail.conf`, in which the
important fields are:

```text
mail_home = /srv/data01/mail/%n/home
mail_location = maildir:/srv/data01/mail/%n
```

Make sure you understand their [meaning](http://wiki2.dovecot.org/MailLocation)
and pick your values with care, taking full advantage of the available
[variables](http://wiki2.dovecot.org/Variables).


To enable Sieve, change `/etc/dovecot/20-lmtp.conf`:
```text
protocol lmtp {
  postmaster_address = hugues@bruant.info
  mail_plugins = $mail_plugins sieve
}
```

**NOTE** Beware of typos in the configuration, in some cases it will simply
prevent Dovecot from starting and the reason will not be immediately apparent
buntil you look into `/var/log/upstart/dovecot.log`.


### Postfix

Postifx is our SMTP server, the crucial component that ensures that both incoming
and outgoing emails get routed correctly.

The main postfix configuration is stored in `/etc/postfix/main.cf`. Mine uses
virtual mailboxes, pipes all emails to Dovecot LMTP, enables TLS and proxies SASL
auth through Dovecot:

```text
myhostname = bruant.info
myorigin = $myhostname
mydestination =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

relayhost =
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all

virtual_mailbox_domains = $myhostname
virtual_alias_maps = hash:/etc/postfix/virtual
virtual_transport = lmtp:unix:private/dovecot-lmtp

smtp_tls_security_level = may
smtp_tls_note_starttls_offer = yes

smtpd_use_tls=yes
smtpd_tls_loglevel = 1
smtpd_tls_auth_only = no
smtpd_tls_security_level = may
smtpd_tls_received_header = yes
smtpd_tls_cert_file = /etc/ssl/certs/smtpd.crt
smtpd_tls_key_file = /etc/ssl/private/smtpd.key
smtpd_tls_CAfile = /etc/ssl/certs/cacert.pem
smtpd_tls_session_cache_timeout = 3600s
tls_random_source = dev:/dev/urandom

smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_local_domain = $myhostname
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
```


In `/etc/postfix/master.cf` make sure the smtp and submission protocols are
handled correctly. It is particularly important to get the "chroot" option
right.

```text
smtp      inet  n       -       n       -       -       smtpd
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_path=private/auth
  -o smtpd_sasl_security_options=noanonymous
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_sender_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=reject_non_fqdn_recipient,permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```


### Testing

Restart all services to ensure they pick up configuration changes:
```bash
service dovecot restart && service postfix restart
```

Use telnet or netcat to check that all services are up and running. Try on the server
first and then on a local machine. The relevant ports are 25 and 587 for SMTP and
143 and 993 for IMAP. For instance:

```bash
$ netcat bruant.info 143
* OK [CAPABILITY IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE IDLE STARTTLS LOGINDISABLED] Dovecot ready.
^C
$ $ netcat bruant.info 587
220 bruant.info ESMTP Postfix (Ubuntu)
^C
```

It is recommended to watch `/var/log/mail.log` while testing to detect any anomaly:
```bash
tail -f /var/log/mail.log
```


### Client configuration

Provided you did not diverge too much from the above instructions, your server
should be reachable by any email client if you feed it the following parameters:

* SMTP: port 587, with PLAIN auth and TLS
* IMAP: either of
  * port 143, with PLAIN auth and STARTTLS
  * port 993, with PLAIN auth and TLS

I opted to exclude the domain name from the login used for SMTP/IMAP auth but
both Dovecot will accept it (as long as it matches the expectation of the
authentication backend you picked).

Try sending an email to your freshly created address, and see if it arrives to
your email client (and keep watching `/var/log/mail.log` to look for problems).

Then try sending an email from your freshly created address to any of your old
ones and see if it arrives.
