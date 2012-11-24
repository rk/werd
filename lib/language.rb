require 'parslet'
require 'parslet/convenience'
require 'pp'
require 'set'

class Language
  attr_accessor :rules
  attr_accessor :morphology

  def initialize file=nil
    @rules = {}
    @morphology = Morphology.new

    load(file) if file
  end

  def load file
    source = File.read(file)
    result = Config.new.apply(Parser.new.parse_with_debug(source))

    result.each do |obj|
      if obj.respond_to? :id
        @rules[obj.id] = obj
      elsif obj.respond_to? :apply_to
        @morphology << obj
      else
        raise Exception.new "Unknown class remaining after parsing: #{obj.class}"
      end
    end

    @morphology.compile(@rules)
    @rules.cycle(2).each { |k,r| r.compile(@rules) if k != 'W' }
  end

  # Generates one random word.
  def word
    word = @rules['W'].random

    # Because we might return another capital letter, and gsub will not replace all the
    # newly inserted capitals, a while loop becomes necessary.
    while word.sub!(/[A-Z]/) { |l| @rules[l].random }
    end

    # Handles optional sub-patterns.
    word.gsub!(/\(([^()]+?)\)/) { rand(100) < 50 ? $1 : '' }

    if @morphology.any? && $options.morphology == true
      word = @morphology.apply_to(word)
    end

    word.gsub!('-','') unless $options.keep_syllables

    word
  end

  class Morphology < Array
    def apply_to(word)
      inject(word) do |result, transform|
        old = result.dup
        result = transform.apply_to(result)
        puts "#{old} -> #{result}" if $options.debug && old != result
        result
      end
    end

    def compile(rules)
      each { |transform| transform.compile(rules) }
    end
  end

  # Stores a single rule, identified by a single letter; it contains an array of
  # characters and is capable of returning a random item from itself.
  class Rule
    attr_accessor :id
    attr_accessor :chars
    attr_accessor :compiled

    def initialize(id, chars)
      @id = id
      @chars = chars.split(/ +/)
      @compiled = id == 'W' || (/[(A-Z]/ =~ chars).nil?
    end

    def random
      @chars[rand(@chars.size)].dup
    end

    # Compiles, or flattens, a given rule.
    def compile(rules)
      @chars.map! do |group|
        unless /[(A-Z]/ =~ group
          group
        else
          columns = pattern_to_data(group, rules)
          first, *rest = columns

          unless rest.empty?
            # pp group, columns
            first.product(*rest).map(&:join)
          else
            first
          end
        end
      end

      @chars.flatten!
    end

    # Compiles a pattern to all its permutations, for optimization purposes
    # and for total set iteration. Still doesn't necessarily support deep
    # -nested optional groups...
    def pattern_to_data(pattern, rules)
      columns = []
      optional = []

      pattern.scan(/[^A-Z()]+|[A-Z()]/).each do |c|
        case c
        when 'A'..'Z' then
          (optional.empty? ? columns : optional.last) << rules[c].chars.dup
        when '(' then
          optional << []
        when ')' then
          # compile the permutations...
          set = optional.pop
          set = set[0].product(*set[1,-1]).map(&:join) if set.size > 1
          set.flatten!
          set << ''

          columns << set
        else
          (optional.empty? ? columns : optional.last) << [c]
        end
      end

      columns
    end
  end

  # This class handles the regular expression matching and replacement to simulate
  # linguistic morphology. This is my own innovation to the original script.
  class Transformation
    attr_accessor :pattern
    attr_accessor :replacement

    def initialize(pattern, replacement)
      @pattern = pattern
      @replacement = replacement
    end

    def apply_to(string)
      string.gsub(@pattern, @replacement)
    end

    def compile(rules)
      @pattern.gsub!(/(\||\&)([A-Z])/) { rules[$2].chars.join($1 == '|' ? $1 : '') }
      @pattern = Regexp.new(@pattern)
    end
  end

  private

  # Builds an full-permutation enumerator for an array of arrays; the first item cycles once,
  # the rest cycle infinitely odometer-style. EG, the incrementation rolls up from right to
  # left-most. Ends when the first letter and the whole pattern has cycled to its end.
  def word_iterator(data)
    first = data[0].cycle(1)
    parts = data[1,-1].map(&:cycle)

    Enumerator.new do |result|
      num = parts.size
      start = parts.map(&:peek)

      # The first iterator I limited to cycle once, so we'll just base our iteration off it.
      first.each do |letter|
        # This will produce all a__ combinations, iterating from right to left.
        begin
          result << letter + parts.map(&:peek).join
          parts[-1].next

          # This will roll the iteration from right to left odometer-style.
          # When the right iterator (i) has rolled to its beginning it increments
          # the one before it (i-1).
          (num - 1).downto(1) do |i|
            parts[i-1].next if parts[i].peek == start[i]
          end
        end while parts.map(&:peek) != start
      end
    end
  end

  # +Parser+ is the parser class descended from Parslet. Create one and use the +apply+
  # method to parse the source. The returned array needs to be passed to +Config+ to be
  # transformed into rules.
  class Parser < Parslet::Parser
    rule(:eol) { str("\n") >> str("\r").maybe }
    rule(:space) { match("[\t ]") }
    rule(:spaces) { space.repeat }
    rule(:spaces?) { spaces.maybe }

    rule(:letters) { match("[^ \t#\n]").repeat(1) }
    rule(:lettergrp) { letters >> (space >> letters).repeat }
    rule(:colon) { str(':') }

    rule(:comment) { str('#') >> (eol.absnt? >> any).repeat }
    rule(:chargroup) { match('[A-Z]').as(:id) >> spaces? >> colon >> spaces? >> lettergrp.as(:chars) }

    # matches:
    # /(pattern)/ > "replacement \1"
    rule(:morph_from) { str('/') >> ((str('\\') | str('/').absnt?) >> any).repeat.as(:regex) >> str('/') }
    rule(:morph_to) { str('"') >> ((str('\\') | str('"').absnt?) >> any).repeat.as(:replace) >> str('"') }
    rule(:transform) { morph_from >> spaces >> str('>') >> spaces >> morph_to }

    rule(:expression) { (chargroup | transform) >> (spaces >> comment).maybe }

    rule(:line) { eol | ((expression | comment) >> eol.maybe) }
    rule(:start) { line.repeat }
    root(:start)
  end

  # +Config+ is the class that turns the various arrays and hashes into useful data
  # In this case a +Rule+ is constructed for each definition.
  class Config < Parslet::Transform
    rule(:regex => simple(:rege), :replace => simple(:replac)) { Transformation.new(rege.to_s, replac.to_s) }
    rule(:id => simple(:i), :chars => simple(:char)) { Rule.new(i.to_s, char.to_s) }
  end

end