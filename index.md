---
layout: base
title: "Discontinuous accretion of curiosities"
---

{% for post in site.posts %}
  <h1 class="posttitle"><a href="{{ post.url }}">{{ post.title }}</a></h1>
  <div class="postmeta"><div class="postdate">Posted on {{ post.date | date: "%F" }}</div></div>
  <!-- <div class="postsummary"><p>{{ post.summary }}</p></div> -->
{% endfor %}

