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

require 'strscan'

module Jekyll
    #
    # This plugin aims to mitigate the abysmal failure of Liquid's expression
    # evaluation engine by introducing a couple of new tags
    #

    #
    # {% expr %} tag : powerful, yet safe, expression evaluation
    #
    # This tag aims to offer an alternative to the awkward chaining of
    # syntactically-challenged filters. The tag accepts a large subset
    # of Ruby expressions:
    #     * full set of operators (unary, binary, ternary) is supported
    #       with correct precedence and associativity
    #     * Integer, String, Symbol, Array and Hash literals
    #     * large whitelist of methods for Core types (no params and
    #       no side-effects)
    #     * access to all variables accessible in a Liquid context
    #     * Liquid-like permissive syntax: a.b -> a['b']
    #
    # Examples:
    # {% expr article.sections[page.index - 1].url %}
    # {% expr ("hello" + 'world')[2..2*3].size.to_s[0] %}
    # {% expr { a: [{"b" => 42}]}[:a][0].b %}
    #
    class ExprTag < Liquid::Tag
        def render(context)
            Expr.new(@markup).evaluate(context)
        end
    end

    #
    # {% expr %}-powered {% if %} block
    #
    # This block is a drop-in replacement for the builtin {% if %} block
    # that leverages the expression evaluator used by the {% expr %} tag
    #
    class IfExprBlock < Liquid::Block
        def initialize(tag, markup, tokens)
            @blocks = []
            push_block('if', markup)
            super
        end

        def unknown_tag(tag, markup, tokens)
            if ['elsif', 'else'].include?(tag)
                push_block(tag, markup)
            else
                super
            end
        end

        def render(context)
            context.stack do
                @blocks.each do |block|
                    if block[:cond].evaluate(context)
                        return render_all(block[:data], context)
                    end
                end
                ''
            end
        end

        def push_block(tag, markup)
            @blocks << {
                cond: tag == 'else' ? Expr.new("true") : Expr.new(markup),
                data: @nodelist = []
            }
        end
    end

    #
    # Simple recursive-descent parser that can evaluate a large subset of Ruby
    # expressions, with variable resolution from a Liquid context
    #
    class Expr
        def initialize(str)
            @str = str
        end

        def evaluate(context)
            eval_expr_full(StringScanner.new(@str), context)
        end

    private

        #
        # Main evaluator entry point: the whole string is expected to be a valid
        # expression.
        #
        def eval_expr_full(ss, context)
            r = eval_expr(ss, context)
            peek(ss)
            raise SyntaxError, ss.pos, "Unexpected " + ss.rest unless ss.eos?
            r
        end

        #
        # sub-expression evaluation: unfazed by trailing characters
        #
        def eval_expr(ss, context)
            eval_ternary(ss, context)
        end

        def eval_ternary(ss, context)
            x = eval_range(ss, context)

            if peek(ss) == '?'
                consume(ss, 1)
                y = eval_expr(ss, context)
                expect(ss, ':')
                z = eval_expr(ss, context)

                x ? y : z
            else
                x
            end
        end

        def eval_range(ss, context)
            x = eval_logical_or(ss, context)
            case c = read_any(ss, %w[... ..])
            when nil
                x
            else
                y = eval_logical_or(ss, context)
                Range.new(x, y, c == '...')
            end
        end

        def eval_logical_or(ss, context)
            eval_binary_associative(ss, context, :eval_logical_and, %w[||])
        end

        def eval_logical_and(ss, context)
            eval_binary_associative(ss, context, :eval_equality, %w[&&])
        end

        def eval_equality(ss, context)
            eval_binary(ss, context, :eval_inequality, %w[<=> == === != =~ !~])
        end

        def eval_inequality(ss, context)
            eval_binary(ss, context, :eval_bitwise_or, %w[> >= < <=])
        end

        def eval_bitwise_or(ss, context)
            eval_binary_associative(ss, context, :eval_bitwise_and, %w[| ^])
        end

        def eval_bitwise_and(ss, context)
            eval_binary_associative(ss, context, :eval_shift, %w[&])
        end

        def eval_shift(ss, context)
            eval_binary(ss, context, :eval_additive, %w[<< >>])
        end

        def eval_additive(ss, context)
            eval_binary_associative(ss, context, :eval_multiplicative, %w[+ -])
        end

        def eval_multiplicative(ss, context)
            eval_binary_associative(ss, context, :eval_unary_minus, %w[* / %])
        end

        def eval_unary_minus(ss, context)
            eval_unary(ss, context, :eval_pow, %w[-])
        end

        def eval_pow(ss, context)
            eval_binary(ss, context, :eval_not, %w[**])
        end

        def eval_not(ss, context)
            eval_unary(ss, context, :eval_method, %w[! ~])
        end

        def eval_method(ss, context)
            x = eval_literal(ss, context)
            until (c = read_any(ss, ['.', '['])) == nil
                p = ss.pos
                case c
                when '.'
                    # only deref if immediately followed by an identifer
                    if /\W/ =~ ss.peek(1)
                        ss.unscan
                        break
                    end
                    y = eval_identifier(ss)
                    raise ArgumentError, p, "cannot deref nil" if x == nil
                    x = resolve_ref(x, y)
                when '['
                    y = eval_expr(ss, context)
                    expect(ss, ']')
                    x = x[y]
                end
            end
            x
        end

        def resolve_attr(x, y)
            if x.respond_to?(:[]) and
                    ((x.respond_to?(:has_key?) and x.has_key?(y)) or
                     (x.respond_to?(:fetch) and y.is_a?(Integer)))
                x[y].to_liquid
            else
                nil
            end
        end

        def resolve_ref(x, y)
            r = resolve_attr(x, y)
            # resolve some whitelisted methods
            r == nil && x.respond_to?(y) && WHITELIST.has_key?(y) ?
                    x.send(y).to_liquid : r
        end

        #
        # A whitelist of side-effect-free methods that take no parameters
        #
        # NB: this list is based on Ruby core types. These methods may not be
        # safe for some exotic custom objects...
        #
        # Ruby 2.0 introduces the Set class in the core but to be compatible
        # with 1.9 we use a hash instead
        #
        WHITELIST = Hash[ %w[
                abs
                bytes
                capitalize ceil chars chop codepoints compact
                downcase drop
                first flatten floor
                hex
                intern invert
                keys
                last length lstrip
                next
                oct ord
                reverse rotate rstrip
                size slice sort strip succ swapcase
                to_a to_c to_f to_h to_i to_r to_s to_sym transpose truncate
                uniq upcase
                values
            ].map { |k| [k, k] }
        ]

        def eval_literal(ss, context)
            c = read(ss)
            case c
            when '('
                x = eval_expr(ss, context)
                expect(ss, ')')
                x
            when '['
                eval_array_literal(ss, context)
            when '{'
                eval_hash_literal(ss, context)
            when '"', "'"
                eval_string_literal(ss, c)
            when ':'
                eval_identifier(ss).to_sym
            when nil
                raise SyntaxError, "Expected literal"
            else
                x = c + ss.scan(/\w+/).to_s

                if SPECIAL_LITERALS.has_key?(x)
                    SPECIAL_LITERALS[x]
                elsif /\d/ =~ c
                    # TODO: support floats as well
                    Integer(x)
                else
                    # resolve context variable
                    context[x]
                end
            end
        end

        #
        # Evaluate an array literal
        #
        # ss:       string scanner
        # context:  Liquid context
        #
        def eval_array_literal(ss, context)
            x = []
            while not ss.eos?
                x << eval_expr(ss, context)
                c = read(ss)
                case c
                when ']'
                    return x
                when ','
                    next
                else
                    raise SyntaxError, ss.pos, 'Unexpected ' + c
                end
            end
            raise SyntaxError, ss.pos, "Expected ']'"
        end

        #
        # Evaluate a hash literal
        #
        # ss:       string scanner
        # context:  Liquid context
        #
        def eval_hash_literal(ss, context)
            x = {}
            while not ss.eos?
                k = eval_hash_key(ss)
                v = eval_expr(ss, context)
                x[k] = v

                c = read(ss)
                case c
                when '}'
                    return x
                when ','
                    next
                else
                    raise SyntaxError, ss.pos, 'Unexpected ' + c
                end
            end
            raise SyntaxError, ss.pos, "Expected '}'"
        end

        def eval_hash_key(ss)
            case c = read(ss)
            when '"', '"'
                k = eval_string_literal(ss, c)
                expect(ss, '=>')
            when ':'
                k = eval_identifier(ss).to_sym
                expect(ss, '=>')
            else
                k = (c + eval_identifier(ss)).to_sym
                expect(ss, ':')
            end
            k
        end

        #
        # Scan an identifier
        #
        # ss:       string scanner
        #
        def eval_identifier(ss)
            ss.scan(/\w+/).to_s
        end

        #
        # Evaluate a string literal (w/ scanner past opening quote)
        #
        # ss:       string scanner
        # tc:       expected terminating character
        #
        def eval_string_literal(ss, tc)
            x = ""
            while not ss.eos?
                c = ss.peek(1)
                case c
                when '\\'
                    x << ss.getch
                when tc
                    ss.getch
                    break
                end
                x << ss.getch
            end
            raise SyntaxError, ss.pos, 'Expected ' + tc if c != tc
            x
        end

        SPECIAL_LITERALS = {
            'nil' => nil,
            'true' => true,
            'false'=> false
        }

        #
        # Core binary operator evaluator (non-associative)
        #
        # ss:       string scanner
        # context:  Liquid context
        # e:        symbol of evaluator for operator of higher precedence
        # ops:      List of operators having the same precedence (as strings
        #           to be recognized)
        #
        # If either operand is null, an exception is thrown
        #
        # NB: This method relies on the matched operator tokens being identical
        # to the Ruby symbol of the corresponding operator
        #
        def eval_binary(ss, context, e, ops)
            x = send(e, ss, context)
            op = read_any(ss, ops)
            p = ss.pos
            case op
            when nil
                x
            else
                y = send(e, ss, context)
                raise ArgumentError, p,
                        "left operand of " + op + " is null" if x == nil
                raise ArgumentError, p,
                        "right operand of " + op + " is null" if y == nil
                x.send(op.to_sym, y)
            end
        end

        #
        # Core binary operator evaluator (associative)
        #
        # ss:       string scanner
        # context:  Liquid context
        # e:        symbol of evaluator for operator of higher precedence
        # ops:      List of operators having the same precedence (as strings
        #           to be recognized)
        #
        # If either operand is null, an exception is thrown
        #
        # NB: This method relies on the matched operator tokens being identical
        # to the Ruby symbol of the corresponding operator
        #
        def eval_binary_associative(ss, context, e, ops)
            x = send(e, ss, context)
            until (op = read_any(ss, ops)) == nil
                p = ss.pos
                y = send(e, ss, context)
                raise ArgumentError, p,
                        "left operand of " + op + " is null" if x == nil
                raise ArgumentError, p,
                        "right operand of " + op + " is null" if y == nil
                x = x.send(op.to_sym, y)
            end
            x
        end

        #
        # Core unary operator evaluator
        #
        # ss:       string scanner
        # context:  Liquid context
        # e:        symbol of evaluator for operator of higher precedence
        # ops:      List of operators having the same precedence (as strings
        #           to be recognized)
        #
        # If the operand is null, an exception is thrown
        #
        # NB: This method relies on the matched operator tokens being identical
        # to the Ruby symbol of the corresponding operator
        #
        def eval_unary(ss, context, e, ops)
            op = read_any(ss, ops)
            p = ss.pos
            x = send(e, ss, context)
            if op != nil
                raise ArgumentError, p,
                        "operand of " + op + " is null" if x == nil
                x.send(op.to_sym)
            else
                x
            end
        end

        #
        # Try to read any token in a given set
        #
        # ss:       string scanner
        # tokens:   list of tokens to be matched (plain strings)
        #
        # return:   first match, or nil if no match
        #
        def read_any(ss, tokens)
            ss.skip(/\s+/)
            return nil if ss.eos?
            tokens.each do |token|
                if ss.peek(token.length) == token
                    consume(ss, token.length)
                    return token
                end
            end
            nil
        end

        #
        # Either match (and consume) the given token or throw an exception
        #
        def expect(ss, token)
            raise SyntaxError, ss.pos,
                    "Expected " + token unless peek(ss, token.length) == token
            consume(ss, token.length)
        end

        #
        # Consume (aka skip) a given number of input characters
        #
        def consume(ss, n)
            (1..n).each { |i| ss.getch }
        end

        #
        # Move scanner past the next non-whitespace character and return it
        #
        def read(ss)
            ss.skip(/\s+/)
            ss.getch
        end

        #
        # Move scanner to next non-whitespace character and return it
        #
        def peek(ss, len = 1)
            ss.skip(/\s+/)
            ss.peek(len)
        end
    end
end

Liquid::Template.register_tag('expr', Jekyll::ExprTag)
Liquid::Template.register_tag('if', Jekyll::IfExprBlock)
