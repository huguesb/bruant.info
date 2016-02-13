bruant.info
===========

Source code of <https://bruant.info>

Canonical repository: <https://github.com/huguesb/bruant-info>


License
-------


Copyright &copy; 2013-2016, Hugues Bruant <hugues@bruant.info>

* content (i.e. all markdown files) is available under the terms of Creative
  Commons Attribution-ShareAlike 3.0
  See cc-by-sa-3.0.txt for details
* unless otherwise indicated all other files are available under 2-clause BSD
  See bsd.txt for details

Corollary: all generated files fall under CC BY-SA 3.0


Dependencies
------------

* [Ruby](https://www.ruby-lang.org) >= 1.9
* [Jekyll](http://jekyllrb.com) >= 1.2
* [Pygments](http://pygments.org) >= 1.4


Source structure
----------------

    ├── pages       special pages
    ├── resources   static resources
    ├── _articles   long-form articles, split into sections
    ├── _plugins    Jekyll plugins
    └── _layouts    HTML templates


Development flow
----------------

1. Test locally

    jekyll serve

2. Push to github

    git push origin master

3. Deploy

    git push deploy master
