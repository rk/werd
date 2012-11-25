require 'parslet'
require 'parslet/convenience'
require 'pp'
require 'securerandom'

class Language
  attr_accessor :rules
  attr_accessor :morphology

  def self.from_file(file)
    self.new(File.read(file))
  end

  def self.from_string(source)
    self.new(source)
  end

  # expects a string representing the source
  def initialize(source)
    @rules = Rules.new
    @morphology = Morphology.new

    result = Config.new.apply(Parser.new.parse_with_debug(source))

    result.each do |obj|
      case obj
      when Transformation
        @morphology << obj
      when Array
        @rules.add(*obj)
      else
        raise Exception.new("Unknown class remaining after parsing: #{obj.class}")
      end
    end

    @rules.optimize
    @morphology.compile(@rules)
  end

  def empty?
    @rules.empty?
  end

  def generate
    word = rules.random_word

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

  class Rules
    def initialize
      @rules = Hash.new([])
    end

    def add(id, chars)
      @rules[id] = chars
    end

    def [](id)
      @rules[id]
    end

    def random(id)
      r = @rules[id]
      r[SecureRandom.random_number(r.length)].dup
    end

    # Generates one random word.
    def random_word
      word = random('W')

      # Because we might return another capital letter, and gsub will not replace all the
      # newly inserted capitals, a while loop becomes necessary.
      while word.sub!(/[A-Z]/) { |l| random(l) }
      end

      # Handles optional sub-patterns.
      word.gsub!(/\(([^()]+?)\)/) { rand(100) < 50 ? $1 : '' }

      word
    end

    def optimize
      puts "Post rule-table optimization:" if $options.debug
      optimization_order.each do |(id, _)|
        compile(id)
        puts "\t#{id}: #{@rules[id].length} combinations" if $options.debug
      end
    end

    def empty?
      @rules.empty?
    end

    private

    def optimization_order
      matrix = @rules.dup.reject { |key| key == 'W' }
      matrix.each { |key,chars| matrix[key] = chars.join.gsub(/[^A-Z]/, '').scan(/./) }

      # Now determine dependency depth by how many other dependencies the other has.
      matrix.each do |key, deps|
        matrix[key] = deps.flat_map { |key| matrix[key].length + 1 }
      end

      # Now determine the approximate depth of dependencies.
      matrix.each do |key, depth|
        matrix[key] = depth.inject(0, :+)
      end

      # Remove first-order dependencies.
      matrix.delete_if { |_, depth| depth == 0 }

      matrix.to_a.sort { |a,b| a.last <=> b.last }
    end

    # Compiles, or flattens, a given rule.
    def compile(id)
      @rules[id].map! do |group|
        unless /[(A-Z]/ =~ group
          group
        else
          columns = pattern_to_data(group)
          first, *rest = columns

          unless rest.empty?
            # pp group, columns
            first.product(*rest).map(&:join)
          else
            first
          end
        end
      end

      @rules[id].flatten!.uniq!
    end

    # Compiles a pattern to all its permutations, for optimization purposes
    # and for total set iteration. Still doesn't necessarily support deep
    # -nested optional groups...
    def pattern_to_data(pattern)
      columns = []
      optional = []

      pattern.scan(/[^A-Z()]+|[A-Z()]/).each do |c|
        case c
        when 'A'..'Z' then
          (optional.empty? ? columns : optional.last) << @rules[c].dup
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
      @pattern.gsub!(/(\||\&)([A-Z])/) { rules[$2].join($1 == '|' ? $1 : '') }
      @pattern = Regexp.new(@pattern)
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
  # In this case a +Charset+ is constructed for each definition.
  class Config < Parslet::Transform
    rule(:regex => simple(:rege), :replace => simple(:replac)) { Transformation.new(rege.to_s, replac.to_s) }
    rule(:id => simple(:rule), :chars => simple(:array)) { [rule.to_s, array.to_s.split(/ +/)] }
    # rule(:id => simple(:rule)) { rule.to_s }
  end

end
