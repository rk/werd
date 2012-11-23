require 'parslet'
require 'parslet/convenience'
require 'irb'

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

    def initialize(id, chars)
      @id = id
      @chars = chars.split(/ +/)
    end

    def random
      chars[rand(chars.size)].dup
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
    # rule(simple(:id)) { id.to_s }
    # rule(simple(:chars)) { chars.to_s.split(/ +/) }
    # rule(:from => simple(:from), :to => simple(:to)) { Transformation.new(from, to) }
    rule(:regex => simple(:rege), :replace => simple(:replac)) { Transformation.new(rege.to_s, replac.to_s) }
    rule(:id => simple(:i), :chars => simple(:char)) { Rule.new(i.to_s, char.to_s) }
  end

end