---
layout: page
title: VPS Setup
---

After years of thinking about it I finally took the plunge and configured my
own email and web server. When I first considered it, I viewed it as a geeky
rite of passage and I thought redirecting my own email domain to e.g. Google
mail servers would be good enough.

The Snowden leaks made me seriously rethink the importance and scope of this
project. I am not paranoid enough to think I could be considered a target
worthy of snooping, however, as Ken White eloquently puts it, ["I am the other"](http://www.popehat.com/2013/09/06/nsa-codebreaking-i-am-the-other/).

This guide describes the process I went through, in a way that is hopefully clear
enough to be reproducible by like-minded individuals. A basic grasp of UNIX command
line is assumed. Path and domain name information where copied verbatim from my own
setup and will need to be adapted. I tried to strike a balance between accessibility
and concision but I expect it can be improved. [Comments are welcome](mailto:hugues@bruant.info).

Although I opted to use a [VPS](http://en.wikipedia.org/wiki/Virtual_private_server)
because I was traveling too much and didn't have a good enough network connection
at home, all the instructions below should work perfectly with a dedicated server.


Domain and Host
---------------

Select a registar and a hosting provider, pick a domain name and a VPS configuration,
take out your credit card (or bitcoins or whatever means of payment are accepted),
confirm your order and get ready for a serious command line session.

I used [Gandi](https://gandi.net) as both my registar and my VPS provider because
it has very competitive pricing, good service and servers in the EU.

You'll need to configure the DNS records of your freshly acquired domain name to point
to your VPS. Most providers will offer some kind of fancy graphical way of editing
DNS records but I prefer editing the zone file by hand:

{%highlight text%}
@ 10800 IN A 46.226.109.60
* 10800 IN A 46.226.109.60
@ 10800 IN AAAA 2001:4b98:dc2:41:216:3eff:fefd:bf1
* 10800 IN AAAA 2001:4b98:dc2:41:216:3eff:fefd:bf1
@ 10800 IN MX 10 @
{%endhighlight%}

The first line points the domain name to the static IP address assigned to the VPS.
The second line points all subdomains to the same address.

The next two lines have the exact same role but for [IPv6](http://en.wikipedia.org/wiki/IPv6).
You may not need them if you choose not to configure your server to use IPv6.

Finally, the last line is an [MX record](http://en.wikipedia.org/wiki/Mx_record),
to indicate the existence of a mail server. It is commonly pointed to a subdomain
but I intentionally kept my setup simple.


Basic server setup
------------------

I installed [Ubuntu](http://ubuntu.com) [12.04](http://releases.ubuntu.com/precise/)
LTS on my server but any recent Linux distribution should work just as well. If you
are using BSD or some exotic Linux flavor you're on your own but you should be
used to it.

The image offered by your provider may be out-of-date or missing some useful
packages. Here's what I did:

{%highlight bash%}
apt-get update
apt-get upgrade
apt-get purge gandi-hosting-agent
apt-get install htop tmux lynx telnet lsof mercurial git libtool \
python-software-properties software-properties-common strace sqlite3 gnupg
{%endhighlight%}

For password-less login to your server, add your public key to `~/.ssh/authorized_keys`.
If you do not have a RSA keypair yet, generate one **on your local machine**:

{%highlight bash%}
ssh-keygen -t rsa -b 4096
{%endhighlight%}


By default the public key will be placed in `~/.ssh/id_rsa.pub`. Append the content
of this file to `~/.ssh/authorized_keys` on your server. `~/.ssh/id_rsa` is your
private key and should not leave your local machine.

**Keep your private key safe and encrypt it with a strong passphrase**


For security, it is highly recommended to disable root login and password-based
login via SSH. Relevant fields in `/etc/ssh/sshd_config`

{%highlight text%}
PermitRootLogin  no
StrictModes yes
RSAAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords  no
HostbasedAuthentication no
ChallengeResponseAuthentication no
PasswordAuthentication no
{%endhighlight%}


**Make sure to add your public key before you do that**, or you might just find
yourself locked out of your server and forced to re-image it.


Root cert
---------

We're going to generate SSL certs for various services later on. These will need
to be signed by a CA. If you're feeling particularly rich or for some reason don't
want to go through the hassle of adding your own root cert to a bunch of client
machines, go ahead and buy one from a legitimate CA.

Otherwise you can generate a custom CA cert as follows:

{%highlight bash%}
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out cakey.pem -des3
chmod 600 cakey.pem
openssl req -x509 -new -nodes -key cakey.key -days 3650 -out cacert.pem
cp cacert.pem /etc/ssl/certs/
cp cakey.pem /etc/ssl/private/
{%endhighlight%}

**Keep your CA key safe and encrypt it with a strong passphrase**

On every client machine (i.e. one from which you will later want to read or write
emails) you will need to add `cacert.pem` to the list of trusted certificates.

On Linux, and most other flavors of UNIX, this is as simple as copying that file
to `/etc/ssl/certs`. Make sure to give it a name that won't clash with existing
certs (your own name is probably a safe choice).

Save the following script as `gencert.sh` alongside your CA cert. It will be
used later on to sign new certificates.

{%highlight bash%}
#!/bin/sh

key=$1
cert=$2
csr=temp.csr
cakey=cakey.pem
cacert=cacert.pem

touch $key
chmod 600 $key
openssl genrsa 2048 > $key
openssl req -new -key $key -out $csr
openssl x509 -req -in $csr -CA $cacert -CAkey $cakey -CAcreateserial \
    -out $cert -days 3650
rm $csr
{%endhighlight%}

Dont't forget to make it executable:

{%highlight bash%}
chmod +x gencert.sh
{%endhighlight%}

**NOTE** All the certs generated by the above command are valid for 10 years.
You might want to increase or decrease that value depending on what security vs
convenience trade-off you're willing to make.


Email
-----

There are several Open Source alternatives available. I settled on the [Postfix](http://www.postfix.org/)/
[Dovecot](http://www.dovecot.org/) combination which is known to be fairly efficient,
quite flexible and reasonably easy to configure.

Ubuntu 12.04 comes with an outdated version of Dovecot which was a problem for me
because I wanted to use the latest version of the [Pigeonhole](http://pigeonhole.dovecot.org/)
plugin to script my email server. Thankfully, somebody created a [PPA](https://launchpad.net/~kokelnet/+archive/dovecot22)
with a suitably fresh version.

**NB:** The truly paranoid should not trust a random PPA but build the package from source
instead.

{%highlight bash%}
add-apt-repository ppa:kokelnet/dovecot22
apt-get update
apt-get install postfix dovecot dovecot-pigeonhole
{%endhighlight%}


The postfix package will ask you a few questions during setup via an ugly ncurses
interface. You can safely ignore them as we'll edit the configuration manually
anyway.


### Certificates

First, let's take care of the certificates we're going to use to encrypt SMTP
and IMAP connections (oh, by the way, I'm not going to bother with POP3 but
it's supported by dovecot and I hear it 's not hard to setup).

{%highlight bash%}
./gencert.sh /etc/ssl/private/smtpd.key /etc/ssl/certs/smtpd.crt
./gencert.sh /etc/ssl/private/dovecot.pem /etc/ssl/certs/dovecot.pem
{%endhighlight%}

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
{%highlight text%}
protocols = imap lmtp
{%endhighlight%}

The second most important config file is `/etc/dovecot/conf.d/10-master.conf`,
where you should adjust LMTP and SASL settings as follows:

{%highlight text%}
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
{%endhighlight%}

Then, each component can be configured via it's own config file in `/etc/dovecot/conf.d`.
This document only address the handful I tweaked but it's acceptable (in fact even
recommended) to poke around and adapt the system to your particular needs.


SASL is configured via `/etc/dovecot/10-auth.conf`. Mine looks roughly like this:
{%highlight text%}
disable_plaintext_auth = yes
auth_mechanisms = plain
!include auth-passwdfile.conf.ext
{%endhighlight%}

The apparent contradiction between the first two lines lies in the fact that
plaintext auth is perfectly acceptable over a TLS connection.

As already mentioned, Dovecot [authentication](http://wiki2.dovecot.org/Authentication)
is pretty versatile. I opted for a simple [passwdfile](http://wiki2.dovecot.org/AuthDatabase/PasswdFile)
but another option may be better for you.


Make sure `/etc/dovecot/10-ssl.conf` points to the key and certificate you generated:

{%highlight text%}
ssl_cert = </etc/ssl/certs/dovecot.pem
ssl_key = </etc/ssl/private/dovecot.pem
{%endhighlight%}


The location of maildirs is controlled by `/etc/dovecot/10-mail.conf`, in which the
important fields are:

{%highlight text%}
mail_home = /srv/data01/mail/%n/home
mail_location = maildir:/srv/data01/mail/%n
{%endhighlight%}

Make sure you understand their [meaning](http://wiki2.dovecot.org/MailLocation)
and pick your values with care, taking full advantage of the available
[variables](http://wiki2.dovecot.org/Variables).


To enable Sieve, change `/etc/dovecot/20-lmtp.conf`:
{%highlight text%}
protocol lmtp {
  postmaster_address = hugues@bruant.info
  mail_plugins = $mail_plugins sieve
}
{%endhighlight%}

**NOTE** Beware of typos in the configuration, in some cases it will simply
prevent Dovecot from starting and the reason will not be immediately apparent
buntil you look into `/var/log/upstart/dovecot.log`.


### Postfix

Postifx is our SMTP server, the crucial component that ensures that both incoming
and outgoing emails get routed correctly.

The main postfix configuration is stored in `/etc/postfix/main.cf`. Mine uses
virtual mailboxes, pipes all emails to Dovecot LMTP, enables TLS and proxies SASL
auth through Dovecot:

{%highlight text%}
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
{%endhighlight%}


In `/etc/postfix/master.cf` make sure the smtp and submission protocols are
handled correctly. It is particularly important to get the "chroot" option
right.

{%highlight text%}
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
{%endhighlight%}


### Testing

Restart all services to ensure they pick up configuration changes:
{%highlight bash%}
service dovecot restart && service postfix restart
{%endhighlight%}

Use telnet or netcat to check that all services are up and running. Try on the server
first and then on a local machine. The relevant ports are 25 and 587 for SMTP and
143 and 993 for IMAP. For instance:

{%highlight bash%}
$ netcat bruant.info 143
* OK [CAPABILITY IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE IDLE STARTTLS LOGINDISABLED] Dovecot ready.
^C
$ $ netcat bruant.info 587
220 bruant.info ESMTP Postfix (Ubuntu)
^C
{%endhighlight%}

It is recommended to watch `/var/log/mail.log` while testing to detect any anomaly:
{%highlight bash%}
tail -f /var/log/mail.log
{%endhighlight%}


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


Security
--------

Before installing more fancy services on the box we should make it slightly more
secure.


### Firewall

[iptables](http://www.netfilter.org/projects/iptables/) is very powerful but has
a complex interface with a rather steep learning curve. Thankfully some tools have
been built around it that drastically reduce the cognitive overhead. Ubuntu for
instance, comes with the [Uncomplicated Firewall](https://help.ubuntu.com/community/UFW).

{%highlight bash%}
ufw enable
ufw allow ssh
ufw allow http
ufw allow https
ufw allow smtp
ufw allow submission
ufw allow imap
ufw allow imaps
{%endhighlight%}


### Detecting intrusion attemps

[Psad](http://www.cipherdyne.org/psad/) monitors network traffic and looks for
suspicious patterns.

The following commands will install psad and tweak iptables as required
{%highlight bash%}
apt-get install psad
ufw logging on
iptables -A INPUT -j LOG
iptables -A FORWARD -j LOG
ip6tables -A INPUT -j LOG
ip6tables -A FORWARD -j LOG
{%endhighlight%}

You should also specify in `/etc/psad/psad.conf` a (list of) valid email
address(es) to which automated reports will be sent.


### Ban intruders

Even if you lock down all ports, make your SSH configuration rock solid and use
secure credentials for your emails, you're bound to see a flow of attempted
intrusions. While these are unlikely to succeed they pollute logs and waste
resources so you may choose to automatically ban offending IPs via
[DenyHosts](http://denyhosts.sourceforge.net/) and [Fail2Ban](http://www.fail2ban.org).

{%highlight bash%}
apt-get install denyhosts fail2ban
{%endhighlight%}

Again, you'll want to tweak the default configuration, at least to send
emails to the correct address. The relevant variables are:
* `ADMIN_EMAIL` in `/etc/denyhosts.conf`
* `destemail` in `/etc/fail2ban/jail.conf`

By default, fail2ban only looks for (and acts upon) intrusion attempts via SSH.
There are a number of other possible vectors and you should at least enable detection
for `postfix`, `dovecot` and `sasl` in `/etc/fail2ban/jail.conf`.


### Ongoing maintenance

One of the downsides of hosting your own mail/web infrastructure is that you have
to maintain the system. That takes more than reacting to a service outage. You
should regularly check the health of each service, take a close look at the
intrusion attempts, run a more thorough [scan](http://www.nongnu.org/tiger/)
every now and then, stay informed of [newly disclosed vulnerabilities](http://seclists.org/bugtraq/)
and proactively update software to patch them.


Web
---

Your VPS is now working smoothly and providing you with a premium email service.
You might as well install a web server to host your homepage and/or your blog,
thereby taking back some control over your online identity.

Again, there are a variety of viable Open Source alternatives but I'm going to
pick [nginx](https://nginx.org) which is very efficient, quite powerful and
extremely easy to setup.

{%highlight bash%}
apt-get install nginx
{%endhighlight%}

### Basic setup

The default `/etc/nginx/nginx.conf` is sane and the recommended approach is
to create a file in `/etc/nginx/sites-enabled/` to configure each coherent
"site" being served (a multitude of virtual hosts and roots can easily coexist).

The initial configuration for this website is pretty simple:

{%highlight nginx%}
# redirect www subdomain
server {
        server_name www.bruant.info;
        return 301 $scheme://bruant.info$request_uri;
}

server {
        #listen   80; ## listen for ipv4; this line is default and implied

        root /srv/data01/www/bruant.info;
        index index.html index.htm;

        access_log /var/log/nginx/access.bruant.info.log;

        server_name bruant.info;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to index.html
                try_files $uri $uri/ /index.html;
        }
}
{%endhighlight%}

Enabling SSL is apparently pretty easy but I didn't bother yet because most browsers
hate self-signed certs and would probably throw an even bigger fit if presented with
a cert signed by an unknown CA.

What is missing is more significant than what is there. Crucially there is no CGI
configuration in sight, which means this site is made of good old static HTML.
If you want to use Perl, PHP, Python, Ruby, or whatever language the cool kids use
these days you'll have to read through nginx's documentation.


### Generating and deploying content

Static website generators are all the rage lately, especially since the rise of
[Markdown](http://daringfireball.net/projects/markdown/). The ease of editing
simple text files, running a test server locally and managing code with
[git](http://git-scm.org) is unrivaled.

I picked [Jekyll](http://jekyllrb.com/) and I'm pretty satisfied so far but the
git-based deploy process outlined below should be fairly easy to adapt to any
other static website generator.

Ubuntu 12.04 comes with an old version of [Ruby](https://www.ruby-lang.org/en/),
thankfully this can easily be worked around by using [rvm](http://rvm.io). You
need to install Jekyll on both your server and your local machine:

{%highlight bash%}
curl -L https://get.rvm.io | bash -s stable --auto-dotfiles
sudo rvm install 1.9.3
rvm use 1.9.3
gem install jekyll
{%endhighlight%}


On your server, create a bare repo in `/srv/data01/git/hugues.bruant.info.git`
and setup a post-receive hook to automatically publish any changes to the
directory from which nginx serves the files:

{%highlight bash%}
git --bare init
cat - > hooks/post-receive <<END
#!/bin/bash -l

dst=/srv/data01/www/bruant.info
tmp=\$(mktemp -d)

# checkout a temporary work tree
GIT_WORK_TREE=\$tmp git checkout -f

# build site from temporary tree
jekyll build -s \$tmp -d \$dst

# cleanup
rm -rf \$tmp
END
chmod +x hooks/post-receive
{%endhighlight%}


On your local machine create a git repo for your website:

{%highlight bash%}
mkdir website
cd website
git init
git add remote deploy ssh://hugues@bruant.info/srv/data01/git/bruant.info.git
{%endhighlight%}


Design your layout, write your content and preview the result on your local
machine as explained in Jekyll's documentation. Commit the result as you make
progress and when you are satisfied, deploy your changes:

{%highlight bash %}
git push deploy master
{%endhighlight%}


### Statistics

There are a bunch of tools, open or closed, free or commercial, CLI or GUI, that
extract stats from server logs. After considering a couple of alternatives I settled
on [awstats](http://awstats.org). It gives a good overview of traffic statistics via a
decent looking webpage  and it is [pretty easy to install](http://kamisama.me/2013/03/20/install-configure-and-protect-awstats-for-multiple-nginx-vhost-on-debian).

**WARNING:** At the time of this writing (September 13 2013) the above guide contains
a typo that has the unfortunate effect of causing the CGI script to hang. The
fixed contents of `/etc/nginx/cgi-bin.php` are:

{%highlight php%}
<?php
$descriptorspec = array(
    0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
    1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
    2 => array("pipe", "w")   // stderr is a file to write to
);

$newenv = $_SERVER;
$newenv["SCRIPT_FILENAME"] = $_SERVER["X_SCRIPT_FILENAME"];
$newenv["SCRIPT_NAME"] = $_SERVER["X_SCRIPT_NAME"];

if (is_executable($_SERVER["X_SCRIPT_FILENAME"])) {
    $process = proc_open($_SERVER["X_SCRIPT_FILENAME"], $descriptorspec, $pipes, NULL, $newenv);
    if (is_resource($process)) {
        fclose($pipes[0]);

        $head = fgets($pipes[1]);
        while (strcmp($head, "\n")) {
            header($head);
            $head = fgets($pipes[1]);
        }

        fpassthru($pipes[1]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        $return_value = proc_close($process);
    } else {
        header("Status: 500 Internal Server Error");
        echo("Internal Server Error");
    }
} else {
    header("Status: 404 Page Not Found");
    echo("Page Not Found");
}
?>
{%endhighlight%}

Notice that "n" becomes "\n": we're looking for the first blank line that separates
headers from body as specified in [RFC 2616](http://tools.ietf.org/html/rfc2616#section-4)
(NB: the RFC specifies CRLF line separators instead of LF, I'm guessing either
the PHP header() function or nginx takes care of the conversion but I don't have
time to check)


I didn't feel like making my stats accessible to the world and introducing another
password in my life was not a particularly appealing prospect either. Instead, I
decided to adapt the nginx config to expose awstats on localhost only:

{%highlight nginx%}
server {
        listen 127.0.0.1:8080;
        server_name awstats;
        root /srv/data01/www/awstats;

        error_log /var/log/nginx/error.awstats.log;
        access_log off;
        log_not_found off;

        location ^~ /icon {
                alias /usr/share/awstats/icon/;
        }

        location ~ ^/cgi-bin/.*\.(cgi|pl|py|rb) {
                gzip off;
                include fastcgi_params;
                fastcgi_pass    unix:/var/run/php5-fpm.sock;
                fastcgi_index   cgi-bin.php;
                fastcgi_param   SCRIPT_FILENAME    /etc/nginx/cgi-bin.php;
                fastcgi_param   SCRIPT_NAME        /cgi-bin/cgi-bin.php;
                fastcgi_param   X_SCRIPT_FILENAME  /usr/lib$fastcgi_script_name;
                fastcgi_param   X_SCRIPT_NAME      $fastcgi_script_name;
                fastcgi_param   REMOTE_USER        $remote_user;
        }

        location / {
                rewrite ^/([a-z0-9-_.]+)$ /cgi-bin/awstats.pl?config=$1 permanent;
        }
}
{%endhighlight%}

The simplest way to keep the URL-redirecting syntactic sugar working with this
setup is to modify `/etc/hosts` to point `awstats` to 127.0.0.1 on both the server
and all machines from which the stats are accessed.

Next you need to setup SSH tunneling between your server and the client on which
you want to view the stats:

{%highlight text%}
ssh -N -L8080:awstats:8080 bruant.info
{%endhighlight%}

Or, better yet, using [autossh](http://www.harding.motd.ca/autossh/) to avoid
annoying losses of connectivity:

{%highlight text%}
autossh -M 0 -N -L8080:awstats:8080 bruant.info
{%endhighlight%}


Once you're done, you can just visit <http://awstats:8080/bruant.info>. Well,
I can anyway. You will need to adjust the domain name so that link won't work
in your browser even though it works in mine.


Email revisited
---------------

Email headers are trivial to spoof and a ginormous amount of spam is being every
second. To address these problems a variety of extensions to SMTP have been
designed and we're going to enable some of them.

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


Work In Progress
----------------

If you spot errors in the above instructions, please [let me know](mailto:hugues@bruant.info).

Ideally I'd like to [puppetize](http://puppetlabs.com/) or otherwise automate as
much of the process as possible. Any contributions towards that goal would be
much appreciated.

I really want to install my own OpenID provider at some point in the future,
or at the very least route OpenID delegation through my own domain... If you have
done it (or even just attempted it) I'd love to hear about your experience.


Sources
-------

In addition to all the links generously sprinkled over this document, you may
want to take a look at the following resources, which got me started:

* <http://help.ubuntu.com/community/Dovecot>
* <http://help.ubuntu.com/community/Postfix>
* <http://www.andrewault.net/2010/05/17/securing-an-ubuntu-server>

