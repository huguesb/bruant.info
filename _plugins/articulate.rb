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
    # of long-form articles. It takes a source tree of the following form:
    #
    # _articles/
    #     foobar/
    #          _article.yml
    #          01-intro.md
    #          02-foo.md
    #          03-bar.md
    #     bazqux/
    #          _article.yml
    #          01-qux.md
    #          02-baz.md
    #
    # And produces an output of the form:
    #
    # articles/
    #     foobar/
    #          01-intro.html
    #          02-foo.html
    #          03-bar.html
    #          index.html
    #          full.html
    #     bazqux/
    #          01-qux.html
    #          02-baz.html
    #          index.html
    #          full.html
    #
    # Where:
    #     * index.html is a table of contents linking to each section
    #     * full.html is a print-friendly single-page version of the article
    #     * the other files are single-section pages
    #
    # _article.yml is used to set variables (e.g. article title) that can be
    # accessed through Liquid markup in the layouts and individual sections.
    #
    # The YAML frontmatter of an article section differs slightly from that of
    # a regular page:
    #     - the section title MUST be specified in the 'name' variable
    #     - the 'title' variable is ignored: the 'page.title' variable in Liquid
    #     is derived from the article and section titles
    #     - the layout variable is not taken into account:
    #          * the index page uses 'article_index'
    #          * single-section pages use 'article_section'
    #          * the print-friendly combined page uses 'article_full'
    #
    # Sections are ordered within the article by the alphabetical order of the
    # source files, hence the use of numerical prefixes in the example above.
    # Each section is assigned a Liquid-accessible numerical index (0-based).
    #
    # The following variable structure is Liquid-accessible in all article-aware
    # pages (i.e. all articles sections but also the special pages generated
    # from article_full and article_index layouts):
    #
    # article:
    #     tile: Foobar
    #     # any other value specified in _article.yml
    #     full:
    #          url: /articles/foobar/full.html
    #     index:
    #          url: /articles/foobar/index.html
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
                path = File.join(site.source, src)

                dst = site.config['articles_dest']
                dst = './articles' if dst == nil

                site.filter_entries(Dir.entries(path)).each do |article|
                    Article.new(site, src, dst, article).generate()
                end
            end

        end
    end

    #
    # An Article is a collection of Section and a few accompanying SpecialPages
    #
    class Article
        attr_reader :site, :name, :src_dir, :dst_dir

        def initialize(site, src, dst, name)
            @site = site
            @name = name
            @src_dir = File.join(src, name)
            @dst_dir = File.join(dst, name)

            yaml = File.join(@src_dir, '_article.yml')
            @liquid = File.file?(yaml) ? YAML.safe_load_file(yaml) : {}
        end

        def generate()
            @sections = []
            @full = SpecialPage.new(self, 'full')
            @index = SpecialPage.new(self, 'index')

            n = 0
            @site.filter_entries(Dir.entries(File.join(@site.source, @src_dir)))
                .sort.each do |file|
                section = Section.new(self, file, n)
                @site.pages << section
                @sections << section
                n += 1
            end

            # MUST add special pages last to ensure that they are rendered
            # **AFTER** all sections and can therefore safely access fully
            # converted content
            @site.pages << @index << @full
        end

        def to_liquid
            {
                'sections' => @sections.map {|x| x.to_liquid},
                'full' => @full.to_liquid,
                'index' => @index.to_liquid
            }.deep_merge(@liquid)
        end

        def title
            @liquid['title']
        end
    end

    #
    # Simple Page subclass that factors out common code
    #
    class ArticleAwarePage < Page
        def initialize(article)
            @article = article
            @site = @article.site
            @base = @site.source
            @dir = @article.dst_dir
        end

        # overriden to make per-article variables Liquid-available
        def render(layouts, site_payload)
            payload = {
                'article' => @article.to_liquid
            }.deep_merge(site_payload)

            super(layouts, payload)
        end
    end

    #
    # Page subclass used to generate per-section page
    #
    class Section < ArticleAwarePage
        # expose section index to Liquid
        attr_reader :index
        ATTRIBUTES_FOR_LIQUID = Page::ATTRIBUTES_FOR_LIQUID + %w[index]

        def initialize(article, name, index)
            super(article)
            @index = index
            @name = name

            self.process(@name)
            self.read_yaml(File.join(@base, @article.src_dir), @name)

            # enforce title and layout
            # TODO: customize title pattern?
            self.data['title'] = @article.title + ' : ' + self.data['name']
            self.data['layout'] = 'article_section'
        end
    end

    #
    # Page subclass used to generate index page and full-article page
    #
    class SpecialPage < ArticleAwarePage
        def initialize(article, name)
            super(article)

            @name = name + '.html'

            self.process(@name)

            # enforce title and layout
            self.data = {
                'title' => @article.title,
                'layout' => 'article_' + name
            }

            self.content = ""
        end
    end
end
