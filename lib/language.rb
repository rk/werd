require 'parslet'

module Lang
  # Parses a string into the language rules.
  def self.load(source)
    Config.new.apply(Parser.new.parse(source))
    Morphology.postprocess
  end
  
  # Generates one random word.
  def self.word
    word = Rule['W'].random
    
    # Because we might return another capital letter, and gsub will not replace all the
    # newly inserted capitals, a while loop becomes necessary.
    while word.sub!(/[A-Z]/) { |l| Rule[l].random }
    end

    # Handles optional sub-patterns.
    word.gsub!(/\(([^()]+?)\)/) { rand(100) <= 50 ? $1 : '' }
    
    if Morphology.any? && $options.morphology == true
      word = Morphology.apply_to(word)
    end
    
    word.gsub!('-','') unless $options.keep_syllables
    
    word
  end
  
  # +Parser+ is the parser class descended from Parslet. Create one and use the +apply+
  # method to parse the source. The returned array needs to be passed to +Config+ to be
  # transformed into rules.
  class Parser < Parslet::Parser
    rule(:eol) { match('[\r\n]').repeat(1,2) }
    rule(:space) { str(' ').repeat(1) }
    rule(:space?) { space.repeat(0) }
  
    rule(:letters) { match('[^\s]').repeat(1) } # enables some unicode and clever usage
    rule(:lettergrp) { letters >> (space >> letters).repeat >> space? }
    rule(:colon) { str(':') }
  
    rule(:comment) { str('#') >> (eol.absnt? >> any).repeat }
    rule(:chargroup) { match('[A-Z]').as(:id) >> space? >> colon >> space? >> lettergrp.as(:chars) }
  
    # matches:
    # /(pattern)/ > "replacement \1"
    rule(:morph_from) { str('/') >> ((str('\\') | str('/').absnt?) >> any).repeat >> str('/') }
    rule(:morph_to) { str('"') >> ((str('\\') | str('"').absnt?) >> any).repeat >> str('"') }
    rule(:transform) { morph_from.as(:from) >> space >> str('>') >> space >> morph_to.as(:to) }
  
    rule(:line) { chargroup | transform | comment | space? }
    rule(:start) { (line >> eol).repeat >> line.maybe }
    root(:start)
  end

  # +Config+ is the class that turns the various arrays and hashes into useful data
  # In this case a +Rule+ is constructed for each definition.
  class Config < Parslet::Transform
    rule(:from => simple(:from), :to => simple(:to)) { Morphology.add(from,to) }
    rule(:id => simple(:id), :chars => simple(:items)) { Rule[id] = items.split(/\s+/) }
  end

  # Stores a single rule, identified by a single letter; it contains an array of
  # characters and is capable of returning a random item from itself. The class
  # is capable of pretending to be a hash and so contain all the rules.
  class Rule
    @@rules = {}
  
    class << self
      def size
        @@rules.size
      end
      
      def clear
        @@rules.clear
      end
      
      # Constructs a rule based on the +key+ (id), and +value+ passed to it.
      def []=(key, value)
        @@rules[key] = new(key, value)
      end
  
      # Returns the rule for the given id character.
      def [](key)
        @@rules[key]
      end
    
      # Returns all rules.
      def all
        @@rules
      end
    end
  
    attr_accessor :id, :chars
  
    def initialize(id, chars)
      self.id    = id
      self.chars = chars
    end
  
    # Returns a random selection from its characters and clones it.
    def random
      chars[rand(chars.length)].dup
    end
  end
  
  # This class handles the regular expression matching and replacement to simulate
  # linguistic morphology. This is my own innovation to the original script.
  class Morphology
    @@morphs = []
    
    class << self
      def clear
        @@morphs.clear
      end
      
      def add(from,to)
        @@morphs << new(from,to[1..-1])
      end
      
      def any?
        @@morphs.size > 0
      end
      
      def apply_to(word)
        @@morphs.each { |morph| word = morph.apply_to(word) }
        word
      end
      
      # This class method is automatically called *once* after the file is loaded to
      # do a little short-hand replacement upon the various morphologies. This DRYs
      # the script file a bit.
      def postprocess
        @@morphs.each do |morph|
          # this does a simple replacement for character groups, so that:
          #   "(|A)" becomes the equivalent of "(#{Rule['A'].chars.join('|')})"
          morph.from.gsub!(/(\||\&)([A-Z])/) { Rule[$2].chars.join($1 == '|' ? $1 : '') }
          morph.from = Regexp.new(morph.from)
        end
      end
    end
    
    attr_accessor :from, :to
    
    def initialize(from, to)
      self.from = from
      self.to   = to
    end
    
    def apply_to(string)
      string.gsub(from, to)
    end
  end
end