require 'benchmark'
require 'rubygems'
require './lib/language'

source = File.read('alvish.txt')

parser = Lang::Parser.new
transform = Lang::Config.new

Benchmark.bmbm do |x|
  x.report("parse:") do
    100.times { parser.parse(source) }
  end
  
  data = parser.parse(source)
  
  x.report("trans:") do
    100.times { transform.apply(data) }
  end
end