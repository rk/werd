#encoding=utf-8
#
# THIS IS ENTIRELY EXPERIMENTAL AND MAY USE LARGE AMOUNTS OF CPU/RAM
# FOR PROTRACTED PERIODS!

require 'pp'

def word_iterator(data)
  Enumerator.new do |result|
    first, *parts = data
    start = parts.map(&:peek)

    first.each_with_index do |letter, index|
      begin
        result << letter + parts.map(&:peek).join
        parts[-1].next

        (parts.size - 1).downto(0) do |i|

          parts[i-1].next if i > 0 && parts[i].peek == start[i]
        end
      end while parts.map(&:peek) != start
    end
  end
end

class Array
  def permutation_count
    self.map{ |item| item.size }.inject(:*)
  end

  def permutation_size
    self.map do |pa|
      pa.max.length
    end.inject(:+)
  end
end

class Fixnum
  def to_formatted_s
    to_s.reverse.scan(/\d{1,3}/).join(',').reverse
  end
end

class Numeric
  def to_bytesize
    unit = 0
    temp = to_f
    while temp > 1024
      temp /= 1024
      unit += 1
    end
    sprintf('%.2f %s', temp, %w{B kB MB GB TB PB EB ZB YB}[unit]) # 100% future-proof AFAIK
  end
end

$rules = {
  'V' => %w{a e i o u},
  'H' => %w{ä ë ï ö ü},
  'D' => %w{d t th},
  'N' => %w{m l n r s},
  'L' => %w{w p q b d}
}
$rules['Q'] = $rules['V'] | $rules['H']
$rules['C'] = $rules['D'] | $rules['N'] | $rules['L'] | %w{ k c x j v }
$rules['K'] = $rules['N'] | $rules['L']
$rules['P'] = ($rules['Q'].product($rules['C']) | $rules['C'].product($rules['Q'])).map { |i| i.join }

pattern = []
pattern << $rules['H'].cycle(1)
pattern << $rules['C'].cycle
pattern << $rules['V'].cycle

generator = word_iterator(pattern)

loop do
  print generator.next.ljust(8)
end

puts
exit

=begin
FIRST = pattern.map { |p| p.next }
puts FIRST.join

i = 1
parts = FIRST.dup
loop do
  parts[2-i] = pattern[2-i].next
  break if parts == FIRST
  puts parts.join
  i = ((i + 1) % 3) + 1
end
=end
exit

=begin
V = %w{a e i o u} # => soft vowels (ah, eh, ih, oh, uh)
H = %w{ä ë ï ö ü} # => hard vowels (A, E, I, OH, OO)
Q = V | H
D = %w{d t th}
N = %w{m l n r s}
L = %w{w p q b d}
C = D | N | L | %w{ k c x j v }
K = N | L
P = Q.product(C) | C.product(Q) # %w{QC CQ}

# words
#T: %w{QNLQ(D) HKVC(D)}
#W: %w{P-T}
=end

patterns = {}

%w{QNLQ(D) HKVC(D) PQCQ}.each do |pattern|
  patterns[pattern] = pattern.scan(/\(?[a-zA-Z]\)?/).collect do |item|
    letter = item.dup

    case letter
    when /([A-Z])/
      item = $rules[$1].dup or fail "Unknown key #{$1} in $rules"
    when /([^A-Z])/
      item = [ $1 ]
    end

    if letter[0] == ?(
      item << ''
    end

    item
  end
end

auto_answer = []
ARGV.each do |flag|
  if flag =~ /-(y|n|q|yes|no|quit)/i
    auto_answer.unshift $1
  end
end

p auto_answer

patterns.each do |text, pattern|
  count    = pattern.permutation_count
  estSize  = count * pattern.permutation_size

  puts "The pattern #{text} generates #{count.to_formatted_s} entries."
  puts "This will take at least \e[31m#{estSize.to_bytesize} RAM\e[0m."

  response = auto_answer.pop || ''

  while response !~ /^(y|n|q|yes|no|quit)$/i
    print "Continue (Y/N/Q): "
    response = $stdin.gets
  end

  case response
    when /^(y|yes)$/i
      words = pattern.inject do |result,insertion|
        result.product(insertion).map { |i| i.join }
      end.sort_by(&:length)
      p words
    when /^(q|quit)$/i
      exit
  end
end
