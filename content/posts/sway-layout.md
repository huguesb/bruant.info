---
date: 2026-01-19
title: 'I finally got my sway layout to autostart just the way I like it'
summary: 'process wrapping and tree walking for the win'
---

I have been using [sway](https://swaywm.org/) as my default window manager on my laptop for a few years. One of the things that I've found most annoying about it, after over a decade of using KDE, was the lack of automated save and restore of running applications. There is a way to auto-start applications, but not to specify the way the resulting windows will be laid out.

Every time I went looking, I could only find partial, hacky, or unreliable solutions, often full of artificial delays to try to address race conditions. Suffice to say I was not satisfied with anything I found, so I accepted that I had to setup my starting configuration on every reboot.


Another round of experiments
----------------------------

Over the last couple of months, with tremendous help from Claude Code, I have been migrating my janky homelab, haphazardly hand-crafted over the course of ~7 years, to a more reproducible setup, standardizing on a single distro ([Arch](https://archlinux.org/)), and using [Ansible](https://docs.ansible.com/) to provision each machine.

As I was looking through a variety of config files on my main laptop, and deciding what to manage with ansible, I was once again reminded of my desire for a smoother and more automated session startup, so I decided to run a few experiments with Claude.

The results were honestly pretty bad.

Claude was running into the same race conditions that countless humans had to wrestle with before, and despite valiant efforts, none of its approaches were getting anywhere satisfying...

RTFM
----

I was too invested to just give up though, so I took a serious look at the sway manpages, and, right there, staring at me, I found the kernel of a solution: the event stream for created windows includes the `pid` of the process that spawns it!

What if...

What if, instead of trying to painstakingly setup the layout before spawning each new window, and waiting for each window to spawn before moving to the next one...

... we just spawn all the windows at once, let them go wherever they will, track which windows corresponds to which process, and then once all windows are up, we re-arrange them all at once! 

This approach has a number of benefits:
 - all applications can be started in parallel, enabling a much faster startup
 - the config doesn't need to specify any rules to map spawned windows to the appropriate layout spot
 - dealing with applications that spawn variable numbers of windows becomes trivial
 - the whole thing is extremely *robust* and doesn't require any arbitrary delay between steps

Given a clear plan for this better approach, Claude was easily able to execute it. It fumbled on one critical aspect though: the wrapper script that was supposed to introduce the layout metadata in the process tree was `exec`-ing the underlying command instead of creating a subprocess, losing the layout metadata in the process! Oops...

Introducing sway-layout
-----------------------

The prototype worked really well, so I decided to clean it up and make it publicly available, as I figure other people might find it useful.

After a mix of Bash and Python for the prototype, I went with [Go](http://go.dev) for the cleaned up version, to make it easy to deploy a single binary.

The source code is available at the following two mirrors:
 - [github](https://github.com/huguesb/sway-layout)
 - [sourcehut](https://git.sr.ht/~hugues/sway-layout)

Installing it is as simple as:

```
go build
cp sway-layout /usr/local/bin
```

To use it, create your layout config as json, in `~/.config/sway/layouts/startup.json`, for instance

```json
{
  "workspaces": {
    "1": {"splith": ["alacritty -e btop", "alacritty"]},
    "2": {"tabbed": ["firefox"]},
    "3": {"splitv": ["alacritty", {"splith": ["alacritty", "alacritty"]}]}
  }
}
```

and, to make sure it gets invoked by `sway` on startup, add the following stanza to your config (adjusting the path as needed obviously):

```
exec /usr/local/bin/sway-layout
```

Limitations and future work
---------------------------

As it is, `sway-layout` gets the job done, but it's far from perfect.

In particular:
 - it will not track windows from processes that detach from their parent, as detaching will
   break our ability to map process id back to layout metadata. Thankfully, detaching is rarely
   used by graphical applications so it's unlikely to be an issue in practice.
 - applications that spawn multiple window will have all their windows grouped together, in the
   order in which they appeared, which may or may not be the prefered order...
 - there is currently no way to specify a custom window size that deviates from the default
   even allocation of space within a split container.


Beyond that, it would probably be practical to keep track of an evolving layout throughout a
session: by subscribing to sway events, walking the process tree to figure out which command
to record for each new window (with some careful de-duping for commands that spawn multiple
windows), and snapshotting the actual layout via the `get_tree` IPC call every time a window
is created, moved, or resized, it would be possible to implement a fairly robust automated
save/restore, and not merely and autostart. 

I will leave that as an exercise for future me, or some motivated reader :)

