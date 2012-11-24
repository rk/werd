require 'ostruct'
require 'rubygems'
require './lib/language.rb'
require 'irb'

$options = OpenStruct.new
$options.number         = 50
$options.seperator      = "\n"
$options.morphology     = false
$options.debug          = true
$options.keep_syllables = false

IRB.start
lang = Language.new("combatlang.txt")
# lang.rules.reject { |k| k == 'W' } .each { |k,r| r.compile(lang.rules) }

# lang.rules['Q'].compile(lang.rules)
# lang.rules['C'].compile(lang.rules)
# lang.rules['P'].compile(lang.rules)

# p lang.rules['Q']
# p lang.rules['C']
# p lang.rules['P']
# p lang.rules['T']
