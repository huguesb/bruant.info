---
date: 2025-12-19
title: 'Migrating from Jekyll to Hugo'
summary: 'Thanks Claude'
---
TL;DR: This site has been migrated from a decade-old Ruby/Jekyll to [Hugo](https://gohugo.io) with some help from Claude Code.


Once upon a time in 2013
------------------------

My young and enthusiastic self decided it would be kinda cool to have a personal website. After some research, I settled on a static site generator, and [Jekyll](https://jekyllrb.com/) was a lead contender at the time so that's what I picked. I configured my [VPS](/articles/vps-setup) such that I could just `git push` to a remote named `deploy` and through the magic of a strategically placed `post-receive` hook in that bare repository, my website would be automatically re-built and copied to the appropriate location to be served by nginx.

Easy peasy.

The winds of change
-------------------

are always blowing, especially in software. As I got distracted, first by a new job, then by kids, and finally by COVID, I quickly lost track of the upgrade treadmill, and soon enough, even on a relatively stable Debian-base, my setup got broken by one upgrade or another, leaving this site frozen in time as I didn't have the time or motivation to fix the deploy process.


Enter Claude
------------

As the kids are getting older and needing less constant attention, I recently decided to clean up my janky homelab setup, and create a set of scripts and Ansible playbooks to keep it in good shape and make it possible to bring it back up relatively effortlessly if any particular component were to suddenly fail. In the process I decided to experiment with the recently released Opus 4.5 in Claude Code, and I was pleasantly surprised!

Claude is pretty jagged. It excels at some things, and gets weirdly stumped by others. It has occasional flashes of brilliance, as well as silly mistakes. Overall though, it is *competent*, with a *broad knowledge*, the ability to retrieve and accurately analyze various documentations, and do so pretty quickly. It proved *invaluable* while I was wading in Ansible land, making my work faster and less frustrating as it ingested relevant data faster than I would have, and offered solutions that were pretty easy to spot-check and test.

Given this first success, I decided to try an experiment with my old dilapidated website.


Act I: archaeology
------------------

As a first step, I fired up Claude Code in the git repo holding this website source, and asked for a new build script that would be able to build it with appropriately outdated version of the software that it was intended for. This was critical because I had built a couple of custom plugins for Jekyll which were no longer working properly in newer versions due to various API changes.

We're talking about setting up software that was released more than 12 years ago, which given recent upgrade trends might as well be a millennium or two! Ruby 1.9.3 was in fact EOL'd more than a decade ago!

To its credit, Claude immediately realized the challenges and pursued a Docker-based solution to most easily recreate an obsolete environment. After autonomously diagnosing and resolving weird corner cases of uid mapping in my rootless podman setup, it experimented with various sources for the base images, successfully navigated updating the apt repository config to work around archival of EOL Debian releases and in a matter of minutes delivered a fully working [suite of scripts](https://github.com/huguesb/bruant.info/commit/2aeed0fdb005f9f74098244f68b4cf3999121716) to build the appropriate base image and execute Jekyll within it to generate the website via volume mounts.

At that point, Claude had already clearly demonstrated its usefulness: it would have probably taken me 2-10 times as long to navigate the vagaries of dealing with obsolete software and archived repositories, plausibly long enough that I would have thrown up my hands in frustration. Instead I had the delightful feeling of watching an eager young mind do cool stuff quickly, not unlike when I see my own children master new skills!

Act II: migration
-----------------

After reviewing the landscape of static website generators, with particular attention to the slightly unusual plugins that I had built for Jekyll, I narrowed down my options to newer versions/forks of Jekyll, Hugo, and Zola. Jekyll was my only exposure to Ruby and I can't say I particularly enjoyed the language or broader ecosystem so I was all too happy to switch to a faster tool in a language I am more familiar with and comfortable modifying if the need ever arose, so I picked Hugo.

While I could have probably just asked Claude to do the conversion itself directly, and checked the results, I opted to go a different route, to maximize both of our strength. Claude is great at writing code and like all LLMs is more likely to make minor mistakes the longer the task is. I am familiar with code, and like all humans I am more likely to miss small changes when looking at a large corpus than a small one. Having Claude produce migration scripts rather than migrating the whole content of the site allows me to review a much smaller set of files, and to trust that their output will be *deterministic*.

Once again, Claude [performed wonderfully](https://github.com/huguesb/bruant.info/commit/43e9a548e10cd49d09b64479ceed8f3b80936aac) and rather quickly, certainly quicker than I would have, saving me tedious reading of documentation to figure out the differences between the two frameworks and how to bridge the gaps.


Act III: verification
---------------------

Having done the archaeologic dig first, I decided to go even further, and have Claude create diff scripts to analyze the differences between the original Jekyll output and the updated Hugo output. This was again very quick and successful, identifying a few differences and ultimately giving me confidence that all changes were either resolved or sufficiently minor as to be acceptable costs of the migration (for instance some URL structures have changed, with the path of a post being of the form `**/title/index.html` instead of `**/title.html`).


Final flourishes
----------------

Being keenly aware that all LLMs have ingested a massive corpus of HTML/CSS, and are therefore excellent in all frontend matters, an area where my own skills are much less developed, but which is thankfully extremely easy to visually validate, I decided to ask Claude for a few upgrades after the successful migration.

First I had Claude update my CSS to automatically switch between light and dark version of the Solarized color scheme based on browser preference. Then I had it add a discrete drop-down at the right of the navbar to explicitly switch between light and dark, persisting the state in `localStorage`, and gracefully degrading to hiding the picker when JS is disabled.

With a little bit of back-and-forth experimentation, and despite some delay with aggressive browser cache not showing updates, this [whole process](https://github.com/huguesb/bruant.info/commit/af15e70a2892939f0e2042fc4b76225072f51adb) only took a few minutes!

And of course, Claude also helped me write and proofread this very post, finding and correcting a handful of spelling and capitalization errors (and suggesting this final line, for a nice meta touch).
