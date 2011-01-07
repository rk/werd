#encoding:utf-8

# Random Word Generator with simple rules (see datafiles); recursive;
# details on datafile format can be found in the English ruleset;
# by Robert Kosek, robert.kosek@thewickedflea.com.
#
# Based on the Perl version by Chris Pound (pound@rice.edu), which was
# based on Mark Rosenfelder's Pascal implementation.
#
# Improvements:
#  - Now parsed via a PEG parser, with greater flexibility such as
#    slashes within the regular expressions.
#  - Mutations via Regex! Now you can separate syllables with dashes
#    and then perform substitution on it.
#  - Optional sections can be wrapped in parenthesis!
#    CV(N)C => CVC || CVNC
#  - Nestable parenthesis, in case it becomes useful to someone.
#  - Generation of an infinite series of words
#  - Technical support for Unicode (touch not ye first line)
#  - Vertical compaction with tab-delimited list instead of new-lines

require 'ostruct'
require 'optparse'
require 'rubygems'
require './lib/language'

$options = OpenStruct.new
$options.number    = 50
$options.seperator = "\n"
$options.morphology= false
$options.debug     = false
$options.keep_syllables = false

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
  
  opts.on('-m', '--[no-]mutate', 'Perform morphology derivations') do |m|
    $options.morphology = m
  end
  
  opts.on('--keep-syllables', 'Leave syllable breaks in the output') do
    $options.keep_syllables = true
  end
  
  opts.on('--debug', 'Enable debug output') do
    $options.debug = true
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

start = Time.now
Lang.load(File.read($options.file))
printf("Took %.4f seconds to load the config file\n" % (Time.now - start))

if Lang::Rule.size > 0
  srand
  
  if $options.number == -1
    puts "Generating an infinite set of words from #{File.basename($options.file)}"
    loop do
      print Lang.word, $options.seperator
    end
  else
    puts "Generating #{$options.number} words from #{File.basename($options.file)}"
    $options.number.times { print Lang.word, $options.seperator }
  end
  
  puts if $options.seperator == "\t"
else
  raise "Cannot generate words without valid rules!"
end