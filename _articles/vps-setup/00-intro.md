---
name: Introduction
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
