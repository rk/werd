#encoding:utf-8

# Random Word Generator with simple rules (see datafiles); recursive;
# details on datafile format can be found in the English ruleset;
# by Robert Kosek, robert.kosek@thewickedflea.com.
#
# Based on the Perl version by Chris Pound (pound@rice.edu), which was
# based on Mark Rosenfelder's Pascal implementation.
#
# Improvements:
#  - Mutations via Regex! Now you can separate syllables with dashes
#    and then perform substitution on it. (Limitation: the regex cannot
#    contain / slashes.)
#  - Optional sections can be wrapped in parenthesis!
#    CV(N)C => CVC || CVNC
#  - Nestable parenthesis, in case it becomes useful to someone.
#  - Generation of an infinite series of words
#  - Technical support for Unicode (touch not ye first line)
#  - Vertical compaction with tab-delimited list instead of new-lines

srand Time.now.to_i

require 'ostruct'
require 'optparse'

fail "Requires Ruby 1.9.2" unless RUBY_VERSION == '1.9.2'

$options = OpenStruct.new
$options.number    = 50
$options.seperator = "\n"
$options.mutate    = false
$options.mdebug    = false
$options.syllables = false

$rules  = {}
$mutate = []

op = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [FILE] [$options]"

  $options.file = ARGV.first

  opts.on("-n", "--number NUM", Integer, "How many words to generate") do |n|
    $options.number = n
  end
  
  opts.on('-i', '--infinite', 'Generates an infinite set of words') do
    $options.number = -1
  end
  
  opts.on('-c', '--compact', 'Seperates words with a tab') do
    $options.seperator = "\t"
  end
  
  opts.on('-m', '--[no-]mutate', 'Perform derivation mutations') do |m|
    $options.mutate = m
  end
  
  opts.on('--show-syllables', 'Leave syllable breaks in the output') do
    $options.syllables = true
  end
  
  opts.on('--debug', 'Enable debug output') do
    $options.mdebug = true
  end
  
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

begin
  op.parse!
  raise OptionParser::MissingArgument.new("[FILE] must be specified.") if $options.file.nil?
rescue
  puts $!, op
  exit
end

if $options.file && File.exist?($options.file)
  File.open($options.file, 'r') do |f|
    while !f.eof? && line = f.readline
      case line
      when /^([A-Z]):\s*([^#]*)\s*/
        $rules[$1] = $2.strip.split(/\s+/)
      when /^\/([^\/]+)\/\s+\>\s+"([^"]*?)"/
        from = $~[1]
        to   = $~[2]
        
        from.gsub!(/([\|&])([A-Z])/) do
          $rules[$2].join( $1 == '|' ? '|' : '')
        end
        from = Regexp.new(from)
        
        $mutate << [from, to]
      end
    end
  end
end

def make_word rule="W"
  pattern = $rules[rule][rand($rules[rule].length)].dup
  
  # handle optional patterns
  pattern.gsub!(/\(([^()]*?)\)/) { rand(100) < 50 ? $1 : '' }
  
  # handle subpatterns
  pattern.gsub!(/([A-Z])/) { make_word($1) }
  
  
  # handle mutations
  if $options.mutate && rule == 'W'
    mrecord = [pattern.dup] if $options.mdebug
    
    $mutate.each do |(from,to)|
      pattern.gsub!(from, to);
      mrecord << pattern.dup if $options.mdebug && rule == "W" && pattern != mrecord.last
    end
    
    puts mrecord.join(' => ') if $options.mdebug && mrecord.first != mrecord.last
  end
  
  pattern.gsub!('-', '') unless $options.syllables # remove syllable markers
  
  pattern
end

werd = Enumerator.new do |result|
  loop { result << make_word }
end

if $rules.size > 0
  if $options.number == -1
    puts "Generating an infinite set of words from #{File.basename($options.file)}"
    werd.each { |w| print w, $options.seperator }
  else
    puts "Generating #{$options.number} words from #{File.basename($options.file)}"
    werd.take($options.number).each { |w| print w, $options.seperator }
  end
  
  puts if $options.seperator == "\t"
end
