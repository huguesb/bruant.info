---
weight: 7
name: Web server
---
There are a variety of viable Open Source alternatives but this guide focuses on
[nginx](https://nginx.org) which is very efficient, quite powerful and extremely
easy to setup.

```bash
apt-get install nginx
```

### Basic setup

The default `/etc/nginx/nginx.conf` is sane and the recommended approach is
to create a file in `/etc/nginx/sites-enabled/` to configure each coherent
"site" being served (a multitude of virtual hosts and roots can easily coexist).

The initial configuration for this website is pretty simple:

```nginx
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
```

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

```bash
curl -L https://get.rvm.io | bash -s stable --auto-dotfiles
sudo rvm install 1.9.3
rvm use 1.9.3
gem install jekyll
```


On your server, create a bare repo in `/srv/data01/git/hugues.bruant.info.git`
and setup a post-receive hook to automatically publish any changes to the
directory from which nginx serves the files:

```bash
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
```


On your local machine create a git repo for your website:

```bash
mkdir website
cd website
git init
git add remote deploy ssh://hugues@bruant.info/srv/data01/git/bruant.info.git
```


Design your layout, write your content and preview the result on your local
machine as explained in Jekyll's documentation. Commit the result as you make
progress and when you are satisfied, deploy your changes:

```bash
git push deploy master
```


### Statistics

There are a bunch of tools, open or closed, free or commercial, CLI or GUI, that
extract stats from server logs. After considering a couple of alternatives I settled
on [awstats](http://awstats.org). It gives a good overview of traffic statistics via a
decent looking webpage  and it is [pretty easy to install](http://kamisama.me/2013/03/20/install-configure-and-protect-awstats-for-multiple-nginx-vhost-on-debian).

**WARNING:** At the time of this writing (September 13 2013) the above guide contains
a typo that has the unfortunate effect of causing the CGI script to hang. The
fixed contents of `/etc/nginx/cgi-bin.php` are:

```php
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
```

Notice that "n" becomes "\n": we're looking for the first blank line that separates
headers from body as specified in [RFC 2616](http://tools.ietf.org/html/rfc2616#section-4)
(NB: the RFC specifies CRLF line separators instead of LF, I'm guessing either
the PHP header() function or nginx takes care of the conversion but I don't have
time to check)


I didn't feel like making my stats accessible to the world and introducing another
password in my life was not a particularly appealing prospect either. Instead, I
decided to adapt the nginx config to expose awstats on localhost only:

```nginx
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
```

The simplest way to keep the URL-redirecting syntactic sugar working with this
setup is to modify `/etc/hosts` to point `awstats` to 127.0.0.1 on both the server
and all machines from which the stats are accessed.

Next you need to setup SSH tunneling between your server and the client on which
you want to view the stats:

```text
ssh -N -L8080:awstats:8080 bruant.info
```

Or, better yet, using [autossh](http://www.harding.motd.ca/autossh/) to avoid
annoying losses of connectivity:

```text
autossh -M 0 -N -L8080:awstats:8080 bruant.info
```


Once you're done, you can just visit <http://awstats:8080/bruant.info>. Well,
I can anyway. You will need to adjust the domain name so that link won't work
in your browser even though it works in mine.
