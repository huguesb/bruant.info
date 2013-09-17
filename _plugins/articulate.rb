# Copyright (c) 2013, Hugues Bruant <hugues@bruant.info>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice,
#      this list of conditions and the following disclaimer.
#
#    * Redistributions in binary form must reproduce the above copyright notice,
#      this list of conditions and the following disclaimer in the documentation
#      and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Jekyll
    #
    # Articulate is a simple Jekyll generator plugin meant to ease the creation
    # of long-form articles. It is centered around the idea that an article is
    # a collection of sections which can be paginated.
    #
    # It takes a source tree of the following form:
    #
    # _articles/
    #     foobar/
    #          _article.yml
    #          01-intro.md
    #          02-foo.md
    #          99-bar.md
    #     bazqux/
    #          _article.yml
    #          01-qux.md
    #          42-baz.md
    #
    # And may produce an output of the form:
    #
    # articles/
    #     foobar/
    #          01-intro.html
    #          02-foo.html
    #          99-bar.html
    #          index.html
    #          full.html
    #     bazqux/
    #          01-qux.html
    #          42-baz.html
    #          index.html
    #
    # Where:
    #     * index.html is a table of contents linking to each section
    #     * full.html is a print-friendly single-page version of the article
    #     * the other files are single-section pages
    #
    #
    # _article.yml is used to set article-wide Liquid-accessible variables (e.g.
    # article title) and to control creation of special pages.
    #
    # In the above example, foobar/_article.yml looks like:
    #
    # title: Foobar
    # synopsis: Rise and fall of the Foobar empire
    # special: [index, full]
    #
    #
    # A special page is basically an article-aware rendering of a layout from an
    # empty content. The most typical use cases are the index.html and full.html
    # pages in the above example. When a value "foo" is specified in the list
    # of special pages, Articulate will attempt to generate a file name foo.html
    # using layout article_foo
    #
    #
    # The YAML frontmatter of an article section differs slightly from that of
    # a regular page:
    #     - the section title MUST be specified in the 'name' variable
    #     - the 'title' variable is ignored: the 'page.title' variable in Liquid
    #       is derived from the article and section titles
    #     - the layout variable is not taken into account: single-section pages
    #       always use 'article_section'
    #
    # Sections are ordered within the article by the alphabetical order of the
    # source files, hence the use of numerical prefixes in the example above.
    # Each section is assigned a numerical index (0-based), Liquid-accessible as
    # 'page.index'.
    #
    #
    # The following variable structure is Liquid-accessible in all article-aware
    # pages (i.e. articles sections and special pages):
    #
    # article:
    #     title: Foobar
    #     # any other value specified in _article.yml
    #     special:
    #          full:
    #               url: /articles/foobar/full.html
    #          index:
    #               url: /articles/foobar/index.html
    #          ...
    #     sections: [
    #          {
    #               url: /articles/foobar/01-foo.html
    #               path: ./_articles/foobar/01-foo.md
    #               name: Foo is magic
    #               title: Foobar : Foo is magic
    #               index: 1
    #               content: "..."
    #          },
    #          ...
    #     ]
    #
    #
    # Articulate honors the following _config.yml options:
    #     articles:      path in which to look for input articles
    #                    default: ./_articles
    #     articles_dest: path in which to write the generated pages
    #                    default: ./articles
    #
    module Generators
        class ArticleGenerator < Generator
            safe true

            def generate(site)
                src = site.config['articles']
                src = './_articles' if src == nil

                dst = site.config['articles_dest']
                dst = './articles' if dst == nil

                site.sources(src).each do |article|
                    Article.new(site, src, dst, article).generate()
                end
            end
        end
    end

    class Article
        attr_reader :site, :name, :src_dir, :dst_dir

        def initialize(site, src, dst, name)
            @site = site
            @name = name
            @src_dir = File.join(src, name)
            @dst_dir = File.join(dst, name)
            @liquid = YAML.safe_load_file(File.join(site.source, @src_dir, '_article.yml'))
        end

        def generate()
            @sections = []
            @special = @liquid['special'].map {|x| SpecialPage.new(self, x)}

            @site.sources(@src_dir).sort.each do |file|
                @sections << Section.new(self, file, @sections.length)
            end

            @site.pages.concat(@sections)

            # MUST add special pages last to ensure that they are rendered
            # **AFTER** all sections and can therefore safely access fully
            # converted content
            @site.pages.concat(@special)
        end

        def to_liquid
            @liquid.deep_merge({
                'sections' => @sections.map {|x| x.to_liquid},
                'special' => Hash[@special.map {|x| [x.basename, x.to_liquid]}]
            })
        end

        def title
            @liquid['title']
        end
    end

    class ArticleAwarePage < Page
        def initialize(article)
            @article = article
            @site = @article.site
            @base = @site.source
            @dir = @article.dst_dir
        end

        def render(layouts, site_payload)
            super(layouts, site_payload.deep_merge({
                'article' => @article.to_liquid
            }))
        end

        def render_liquid(content, payload, info)
            super(content, payload, info.deep_merge({
                registers: { article: payload['article'] }
            }))
        end
    end

    class Section < ArticleAwarePage
        attr_reader :index
        ATTRIBUTES_FOR_LIQUID = Page::ATTRIBUTES_FOR_LIQUID + %w[index]

        def initialize(article, name, index)
            super(article)
            @index = index
            @name = name

            self.process(@name)
            self.read_yaml(File.join(@base, @article.src_dir), @name)

            # TODO: customize title pattern?
            self.data['title'] = @article.title + ' : ' + self.data['name']
            self.data['layout'] = 'article_section'
        end
    end

    class SpecialPage < ArticleAwarePage
        def initialize(article, name)
            super(article)
            @name = name + '.html'

            self.process(@name)
            self.content = ""
            self.data = {
                'title' => @article.title,
                'layout' => 'article_' + name
            }
        end
    end

    # monkey-patching for the win
    class Site
        def sources(dir)
            filter_entries(Dir.entries(File.join(self.source, dir)))
        end
    end
end
