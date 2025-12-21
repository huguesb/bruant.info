---
date: 2025-12-20
title: 'How I use LLMs, December 2025 edition'
summary: 'with protection'
---

I live in San Francisco, and some of my closest friends have been working at OpenAI, Anthropic, and various other players in the field long before ChatGPT was even released. Suffice to say I would have a hard time avoiding the topic if I wanted to. But I'm very much a nerd myself, and I like both cool toys and efficiency. I've been following the trends over the past few years, although from a bit of a distance, as tech took a backseat for a few years while I was focusing on my adorable small kids and the many moving parts of running a 7-person household (I not-so-jokingly refer to myself as the COO of the family business).

After a few false starts and disappointment, I am at a point where I see LLMs consistently able to unlock a lot of value in my life. This is a small snapshot of my journey so far, for future reference.


(Too) Great Expectations
------------------------

In the summer/fall of 2023, I built a small greenhouse on the upper deck of our house in San Francisco. At the time, this was by far the most challenging physical build project I had undertaken by myself. I had a fair amount of experience building custom furniture out of plywood and dimensional lumber (dining room table, couch, bunk bed, ...) but the complexity of putting up a ~100 square feet freestanding structure with a roof, and framed doors and windows still felt a little bit overwhelming.

I tried to ask ChatGPT and Claude for assistance in designing the structure, and it was thoroughly unhelpful. While they were both able to spout reasonable-sounding babble and draft a list of parts, neither of them could produce anything resembling a satisfying diagram showing how all the parts fit together, or detailed assembly instructions, or an accurate list of parts, with adequate quantities.

It was a total waste of time.


A tale of hostile design and lackluster documentation
-----------------------------------------------------

Our family generates a *lot* of pictures, mostly of the kids, and of highly varying quality. On a typical quarter we usually amass 1 to 2 *thousand* photos, across a handful of user accounts. At the end of the year, when the time comes to pick a selection of favorites for our usual holiday cards, one lucky bastard (usually me) needs to trawl through the heap, panning for gold.

A couple years ago, I had this genius (to me) idea: "I should write an app!"

An app for what? I hear you say. Well, for sorting through pictures faster obviously, and also, ideally, for making it more practical to delegate that task to someone else that may not be as skillfully trained with Google Photos keyboard shortcuts and the corner cases of multiple selection behavior.

So here I am, thinking, well, I could just make a tiny web or mobile app that uses a swipe motion to filter which pictures are Holiday Card Worthy™, or more generally to fit in a small handful of pre-configured categories ("has kid A", "has kid B", "has everyone", ...) so that each person capable of taking a picture would also easily be able to scan through their pictures and build out the relevant buckets.

Crucially, they would be able to take on that task *without* having to learn to be proficient with the (generally not great and definitely not optimized for this use case) Google Photos UX. But even more importantly, it would *allow incremental progress*, and spare them the disaster of *one wrong touch discarding a complex selection build over multiple minutes of painstaking work*.

So naturally, my next thought is: I hear the LLMs are getting better, and are particularly good with frontend stuff, which is very much not my jam, but I understand it enough that I can spot-check it, so I should try that.

And the LLM worked ok, building me a serviceable single-page web app with appropriate calls to Google Photos to retrieve pictures, and correctly handling the input events. So far, so good.

Unfortunately, that app I was so excited about was stillborn. As it turns out, the Google Photos API is a horribly restrictive piece of shit, that intentionally prevents third party users from building any form of album management: while it is possible to create albums, it isn't possible to add existing pictures to a new album! Yes, that's right! A third party app can only add to an album pictures it has itself uploaded! What the actual fuck?!?!?!

The LLMs that I worked with at the time (it was November 2023, so ChatGPT 4 and Claude 2, if I remember correctly), were either unaware of that limitation, or failed to alert me to it. To be fair, it is not well documented, and a search on the topic only turns up an old [StackOverflow post](https://stackoverflow.com/questions/52009840/google-photos-apis-move-existing-image-to-album) itself pointing to a [long-ignored feature request](https://issuetracker.google.com/issues/109505022?pli=1).

At that point, I decided that although it was not a fair test for the LLMs, it was a clear sign that they were not at a point where they could be useful enough to meaningfully augment my productivity, so I largely stopped using them for a year, returning a few times to ask for help with Latex/Typst formatting and command-line audio-processing tools, with mixed success.


In search of lost time
----------------------

I have been wearing glasses since first grade (I think? I'm still not 100% sure how US and French grades map, technically "depuis le CP"). My vision degraded steadily as I grew, only stabilizing in adolescence at a rather high -9 / -10 diopters. I switched to rigid gas-permeable lenses in high school and wore them religiously for over a decade, up until a few years ago, when lifestyle changes from the combo of kids and COVID had me go back to glasses.

After many years of idly thinking about it, but failing to prioritize it, I finally decided to do a deep dive on corrective eye surgery options in the fall of 2025. I took Claude along for the ride, and I was quite impressed with the thorough and useful answers I got. Given prior experiences, I was careful to double and triple-check many of the references, and came out very satisfied with the quality of the original answers.

Claude was sufficiently knowledgeable to give me a solid and easily digestible introduction to a field I was unfamiliar with, backed with verifiable evidence. It was able to help me navigate the search of providers, in particular giving me a number of simple and actionable criteria to assess which ones would be most trustworthy (sharing detailed physical assessment numbers, being honest about various pros and cons of each procedure, ...).

This was a watershed moment for me, the first time where an LLM actually unambiguously crossed a threshold of practical usefulness, helping me accomplish a goal faster and at higher quality than I might have otherwise.

Since then, I have had many more conversations with Claude, and in the majority of cases, I have benefited greatly from them. I was able to brainstorm a design for a site-to-site VPN link between two houses on the same ISP (Sonic) but without static IPs, the design and implementation of a robust backup system for my homelab. I successfully troubleshot and fixed annoying behaviors of my new Framework 13 laptop (finicky lid sensor, which devices trigger resume from sleep, ...).


Your friendly neighborhood contractor
-------------------------------------

Home ownership has pro and cons. One of my favorite benefits of owning as opposed to renting is: **you can just DO things**.

Want to paint a wall? No need to ask permission or redo it when you leave.

Want to put up a shelf? Drill, baby, drill!

Kids asking for a secret door between two rooms? As long as you're ready to manage the obnoxiousness that is drywall, not a problem.

Anyway, a few weeks ago I was doing some re-arranging in an ADU, and thinking, *wouldn't it be so much better if I could have a couple outlets here and there instead of those ugly extension cords?*. And right there on the ceiling I see a little plastic cover that looks like there might have been wiring for an outlet, so I go ahead and open it.

It looks weird.

There's a plastic box that could house an outlet.

There are some cables coming in.

No outlet though.

And the cables are connected by wire nuts in a pattern that just doesn't make sense to me...

And there's something weird going on with the breakers. Why is my non-contact voltage tester behaving this way?!?

Hmm, I don't think I'm going to get an outlet out of that. But, what even is going on? How should I know?

Alright then, let's see if Claude can help.

Turns out, it sure can! Given a brief explanation of the situation, description of the wire connections, and how how the non-contact voltage tester read based on which breakers were on or off, Claude correctly deduced that my house was wired with a bunch of [multi wire branch circuits](https://www.electrical101.com/multiwire-branch-circuit.html), and explained the implications. I didn't even know that was a thing!

Later in the same project, I tried to tap onto a different circuit, and once again found surprising wiring behind a light switch. Claude once again saved the day by correctly diagnosing what was going on, giving me clear ways to validate the hypotheses, and helping me label the mess of wires so I could achieve my goal safely.

And all of this is happening in a matter of seconds to minutes, for a rather trivial price: calling up an electrician to investigate the situation would have taken at best hours, more likely days, and cost me more than a whole year of the basic Claude subscription tier! And, when I do call the electrician next time I have a serious project that I cannot handle myself (like pulling a 240v / 50A line to install a level 2 EV charger), I can save them some time by pre-emptively laying out all the weirdness of the circuit that I have already diagnosed with Claude.


Code me tender, code me true
-----------------------------

The chat interface to LLMs is okay. It works well for narrow questions and a wide range of brainstorming. But where I see LLMs really shine recently, is via the command line interface of Claude Code. It is almost unreasonably effective! Giving Claude access to the battery of UNIX tools and a filesystem is a **MASSIVE** upgrade to its abilities, and many chat interfaces have tried to tap into that power in various ways, but all fall short of the real unfettered thing.

Now, obviously, with great power comes great responsibility and great risk. A poorly prompted LLM, or a confused one, can wreak havoc on a wide open filesystem. Claude Code tries to balance that by asking for permissions, and that's nice, but it's also fairly obnoxious.

My preferred way of dealing with this situation, is to operate in different folders for each project, have each folder be version-controlled, and use bubblewrap with bind-mounts to restrict which parts of the filesystem Claude can read or write, significantly limiting the blast radius of a mistake (or prompt injection from untrusted content). Knowing that Claude (and any child process it spawns) can only make changes within a single version-controlled folder gives me the peace of mind to enable `--dangerously-skip-permissions` and allow Claude to move forward with each task unhindered until it reaches a satisfying conclusion.

My hand-rolled sandbox is somewhat limited though, and in particular it doesn't meaningfully restrict network traffic. I am encouraged that Anthropic is taking [sandboxing considerations seriously](https://www.anthropic.com/engineering/claude-code-sandboxing), and look forward to a time when I can have a fine-grained networking sandbox that allows access to web search without exposing any sensitive parts of my internal network.


Coda: Color me impressed
------------------------

Remember that greenhouse design question I put to the models of yesteryear? I just tried it with Opus 4.5

Oh my god, you sweet sweet overachiever, you...

Did you not only answer my question to a pretty high level of quality, but write me a whole goddamn [website to present the results](https://claude.ai/public/artifacts/e4c10a5b-8ee2-46bc-9057-b7b9423216e1)? And it looks *slick*!

