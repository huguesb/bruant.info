---
name: Security
---

Hosting your own email and web infrastructure is all well and good but if you
don't want to subsidize a botnet you need to lock down your server as tightly
as possible.

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
to maintain the system. You should regularly check the health of each service,
take a close look at the intrusion attempts, run a more thorough [scan](http://www.nongnu.org/tiger/)
every now and then, stay informed of [newly disclosed vulnerabilities](http://seclists.org/bugtraq/)
and proactively update software to patch them.
