---
name: Basic server setup
---

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

