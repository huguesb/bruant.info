---
date: 2016-02-16
title: 'A minimal & up-to-date nginx docker image'
summary: 'Come for the fat-free product, stay for the creative recipe.'
---
TL;DR: I built [something cool](https://github.com/huguesb/alpinx).


My first foray into programming was with a graphing calculator. It boasted an
impressive 64kB of addressable memory and a 6MHz z80 CPU. Back then, I had very
limited access to a computer and I spent an inordinate amount of time writing
and re-writing algorithms with pen and paper, shaving a cycle here and a byte
there, until there was nothing left to take away.

Fast forward to 2016: now working mostly with Java and Docker, I have witnessed
and made design choices that St Exupery would likely disapprove of. Containers
are billed as a lightweight alternative to full-blown virtual machines but
reaping the promised reward takes more careful sowing than one might naively
assume.


Excuse me Sir, Would you like to buy 100MB of userspace?
--------------------------------------------------------

Before containers became mainstream, a large share of servers were based on
Debian or one of its derivative. Unsurprisingly, the path of least resistance
was followed when migrating to containerized environment and, today, a large
share of container images are sill Debian or Ubuntu-based.

During a hackaton last year I took a rather aggressive approach to bloat-reduction:
wholesale [port of Java services to Go](https://www.aerofs.com/resources/blog/a-little-golang-way-md/).
Although it had excellent results, this approach was not always practical, which
led me to look for other avenues to reduce image bloat.

Enter [Alpine Linux](http://www.alpinelinux.org/), an extremely lightweight
distribution based on [Busybox](https://busybox.net/) and augmented with a
large repository of up-to-date [packages](https://pkgs.alpinelinux.org/packages).

The fine folks at [Glider Labs](http://gliderlabs.com) turned it into a minimal
[Docker image](https://hub.docker.com/_/alpine/) and it has enjoyed such popularity
that many images in the official library are now
[being migrated to Alpine](https://www.brianchristner.io/docker-is-moving-to-alpine-linux/).


The engine of growth
--------------------

At work, we've beeen gradually weaning ourselves off our Debian/Ubuntu dependency.
Late weekend, I once again succumbed to the siren call of optimization and decided
to tackle one of the last remaining Debian-based image: nginx.

The [official nginx image](https://github.com/nginxinc/docker-nginx/blob/master/Dockerfile)
is based on Debian Jessie. Weighing in at 133.9MB, it is not exactly lightweight. Luckily,
Alpine comes with a [nginx package](https://pkgs.alpinelinux.org/package/main/x86_64/nginx),
which makes it trivial to build a much smaller image:

```text
FROM alpine:3.3
RUN apk -U add nginx && rm -rf /var/cache/apk/*
```

This one weighs in at a mere 6.3Mb!

Unfortunately, the Alpine maintainers have opted to only package nginx [stable](http://nginx.org/en/CHANGES-1.8),
which lags far behind [mainline](http://nginx.org/en/CHANGES) and lacks the recently
introduced stream and HTTP/2 modules, among other things.


Use the source Luke
-------------------

Caught between a rock and a hard place, I resorted to the tried-and-true approach
of building from source. Before the move to Docker we were provisioning our servers
with a custom build of nginx stored in an internal APT repository. How hard could it
be to do the same for Alpine? Besides, I could reasonably expect a build container
to be easier to work with than the build VM of yore. 

The process turned out to be pretty easy:

 1. Fire up an `alpine:3.3` container and install the `alpine-sdk` package
 2. Clone the package tree
 3. Tweak the existing nginx package
 4. Profit

Alpine's package builder doesn't like being run as root, which is understandable
but becomes a little annoying in a Docker container. It took a couple of passes
over the [documentation](http://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package)
but I eventually puzzled out the required steps and condensed them into a small
shell script.

The current nginx package didn't build out-of-the-box due to an incorrect URL for one
of the source archives and the latest version of nginx required bumping one of the
dependencies but clearing these minor roadblocks took only a few minutes.


Inching towards minimalism
--------------------------

Given a base docker image and a package, one can easily produce a new image with
that package installed by including it in the image build context:

```text
FROM alpine:3.3
COPY packages /packages
RUN apk -U add nginx --repository /packages --allow-untrusted &&\
    rm -rf /var/cache/apk/*
```

That is certainly an improvement over the Debian-based image but it falls short
of minimalism as the local packages remain in the final image after being installed.

Fixing this requires making the local package visible inside a `RUN` statement without
persisting it in a lower layer, which is not as straightforward as one might hope.

There have been proposals to make `docker build` accept volume mappings or to
introduce a new Dockerfile statement to bind-mount items from the build context,
thereby making them available to `RUN` statements without persisting them in the
image but they were all rejected. There are valid reasons for this and the planned
redesign of `docker build` as a client around the remote API offers hope that
this limitation might eventually be lifted. In the meantime, some creativity
is required to achieve the desired outcome.


Dockerception 2.0
-----------------

A `RUN` statement in a Dockerfile is basically equivalent to `docker run` followed
by `docker commit`. This decomposition neatly sidesteps the lack of volume mapping
in the `docker build` command, and makes it possible to install the package from a
volume while keeping it out of the resulting image.

Unfortunately, mounting host folders as volumes is neither _remote-friendly_ nor
_inception-friendly_ as the host location refers to the environment in which the
docker daemon is running, not to the environment from which the `docker run`
command is invoked. This matters a great deal because the two main use cases for
this build script are:

 - dev laptop
    - docker daemon running in a docker-machine guest VM
    - build script invoked from the OSX host
 - CI agent
    - docker daemon running _somewhere_ (CoreOS in AWS or Ubuntu in the office)
    - build script running inside a container with mapped docker socket

I faced a similar issue in [gockerize](https://github.com/aerofs/gockerize) and
solved it by building a derived image including the relevant source files in its
build context instead of mapping the source in the base builder image.

This case is slightly more convoluted:

 1. Create a temporary `context` image, which includes the package to be
    installed in the build context and persists it in a layer

 2. Run this image with:
     * a name (say `context`)
     * a volume (not mapped to any host folder)
     * a command that copies the package into the volume

 3. Run the base image with:
     * the volume created in step 2 (`--volumes-from context`)
     * a command that installs the package from the volume

 4. Commit the result of step 3 and discard intermediate build artifacts

 5. Profit!


Avoiding cache invalidation
---------------------------

For some reason, which is not entirely clear to me but probably comes down
to timestamps, multiple subsequent runs of the above process with idential
input will produce docker images with different content hashes.

This becomes a problem if the image is to be used a the base for more
complex images as it will invalidate the docker cache and force a fresh
build of every layer in any such derived image.

To avoid this issue, I leveraged the timestamp checking I described in my
[previous post](/2016/02/13/avoiding-redundant-container-builds/).


alpinx
------

The result of this bout of feverish tinkering is available on Docker Hub
as [huguesb/alpinx](https://hub.docker.com/r/huguesb/alpinx/) and the source
are on [github](https://github.com/huguesb/alpinx).

The method is easily adaptable to any existing package in the Alpine
tree or to brand new packages and I may at some point turn this into a
more general-purpose tool. Although, quite frankly, I'm hoping I won't
run into outdated packages in the Alpine repository very often.


