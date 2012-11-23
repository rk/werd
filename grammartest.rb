#encoding=utf-8
#
# THIS IS ENTIRELY EXPERIMENTAL AND MAY USE LARGE AMOUNTS OF CPU/RAM
# FOR PROTRACTED PERIODS!

require 'pp'

def word_iterator(data)
  Enumerator.new do |result|
    first, *parts = data
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
pattern << $rules['H'].cycle(1) # produces an enumerator that cycles once
pattern << $rules['C'].cycle # produces an enumerator that cycles infinitely
pattern << $rules['V'].cycle

generator = word_iterator(pattern)

loop do
  print generator.next.ljust(8)
end

puts
