---
date: 2016-02-13
title: 'Avoiding redundant container builds'
summary: 'Teaching a new dog an old trick.'
---
The problem
-----------

The Docker cache largely works as intended, except on 1.9.0 where it sometimes
isn't [invalidated correctly](https://github.com/docker/docker/issues/17290),
however there are a few corner cases where it is not sufficient and builds end
up doing a lot of redundant work.

Consider for instance the case of packaging hundreds of megabytes of assets in
a container image. Even when the content of the Dockerfile is unchanged and
every layer is a cache hit, the entire build context needs to be uploaded to
the docker daemon, which can take a frustratingly long time.

Another situation in which the docker cache falls short is when a slightly
non-standard build process is used, as for instance with [gockerize](https://github.com/aerofs/gockerize),
where the final image is built inside a container and the intermediate step
of compiling the Go sources runs even if the output binary is unchanged.

In both cases, the age-old approach of comparing input and output timestamps
to determine whether to perform the build step could safely shorten build times.


A rough solution
----------------

Dealing with timestamps on the command line is notoriously tricky, especially
when attemting to maintain some semblance of portability. To keep things simple
I figured it would be simpler to work with Unix timestamps.

### Step 1: When was the build context last modified?

Surprisingly enough, there appears to be no simple standard way to obtain the
modification time of a file as a Unix timestamp. The most reliable way I've
found so far is to use `stat` and customize the invocation based on the host OS.

```bash
if [[ $(uname -s) == "Darwin" ]] ; then
    stat_format="-f %m"
elif [[ $(uname -s) == "Linux" ]] ; then
    stat_format="-c %Y"
else
    echo "unsupported platform: always rebuild" 1>&2
    return
fi
```

With this out of the way, it is quite straightforward to derive the most recent
modification timestamp in the build context:
```bash
changed=$(find "$1" -type f | xargs stat $stat_format | sort -nr | head -n 1)
```


### Step 2: When was the docker image created?

Obtaining the creation timestamp of a docker image is easy enough but converting
it to a Unix timestamp is somewhat more involved. After some experimentation,
I settled on querying the docker remote API inside a container and extracting the
timestamp with [jq](https://stedolan.github.io/jq/), which has the dual benefit
of portability and not introducing a new dependency.

```bash
docker build -t test-newer - &>/dev/null <<EOF
FROM alpine:3.3
RUN apk -U add curl jq
EOF
created=$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    test-newer sh -c "curl --fail --unix-socket /var/run/docker.sock \
    http:/images/\$(echo $1 | jq -R -r @uri)/json 2>/dev/null \
    | jq -r '.Created[0:19]+\"Z\" | fromdate'")
```

Using containers to avoid dealing with OS-specific variations in basic Unix tools,
and outdated or missing dependencies is a neat trick that I've started using a
lot lately.


### Step 3: Comparing

Combining the output of the first two steps is pretty straightforward:

```bash
if [[ -n "$changed" ]] && [[ -n "$created" ]] && (( "$created" > "$changed" )) ; then
  echo "fresh"
else
  echo "stale"
fi
```


Refinements
-----------

Although this first solution gets the job done, it lacks elegance and is not
as efficient as it could be since it needs to sort the list of timestamps
for the entire build context.

Looking at the man page for `find` reveals the existence of the promising
`-newermt` filter. Instead of computing the newest timestamp in the build
context one can directly test if any file is newer than a given timestamp,
neatly avoiding the expensive sort and allowing the pipe to be closed early:

```bash
if [[ -z "$(find "$context" -newermt "$created" | head -n 1)" ]] ; then
  echo "fresh"
else
  echo "stale"
fi
```

The catch is that `find` does not allow dates to be specified as Unix timestamps.
There is GNU extension allowing it but that wouldn't work on OSX, which leads
us to revisit an early assumption. Specifically, dealing with Unix timestamps,
which was expected to make things simple, turns out to create more issues than
it solves.

Obtaining the creation timestamp of the docker image in a human-readable (and thus
_find-friendly_) format results is a much simpler script:

```bash
created=$(docker inspect --format='{{.Created}}' --type=image "$1" |\
    cut -d. -f1 | sed 's/T/ /')
if [[ -n "$created" ]] && [[ -z "$(TZ=UTC find "$2" -newermt "$created" | head -n 1)" ]] ; then
  echo "fresh"
else
  echo "stale"
fi
```

Note the `TZ=UTC` above. Abandoning Unix timestamps means we have to be careful to
compare date/times in the same time zone. The docker daemon sanely gives UTC timestamps
so we need to make sure `find` doesn't mistakenly assume it to be in the local timezone.

A cleaned-up version of this script is [available on github](https://github.com/huguesb/img_fresh)

Room for improvement
--------------------

This approach is not quite optimal as docker will not update the creation
timestamp of the image when a build hits the cache for all layers. This could
lead to a situation where the timestamp check always flag the image as stale
if a file in the build context sees its timestamp change in a way that does
not invalidate the docker cache (unchanged content, .dockerignore, ...)

A possible workaround, which may be acceptable if the build process is
expensive but the final image small, as is the case for [gockerize](https://github.com/aerofs/gockerize),
is to disable the docker cache when building the final image.


