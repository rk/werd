Werd.rb
=======

Werd.rb is a word generator based off the Perl version (by [Chris Pound][cpound]) of [Mark Rosenfelder's][markr]
Pascal word generator.  Werd.rb is compatible with any of his [rule files][cpound].  I have made some extensive
additions of my own to werd.rb, and my methods (even in the old implementation) were discovered more than read
from Perl (face it, Perl is downright unreadable without _study_).

Run with `ruby werd.rb -h` for options and help.

Improvements
------------

* PEG-based parser, powered by [Parslet][parslet].
* Optional patterns, including nested ones. "CV(C)" gives that last C pattern a 50% chance to be retained.
* Unicode support.
* Morphology! Werd.rb can apply some morphology rules to your language to change sounds and letter groups, etc.

Prerequisites
-------------

* Ruby 1.8.7 or 1.9.2 (suggested)
* Ruby Gems
* Parslet

Morphology
----------

Okay, this section is the one that takes the most teaching.  No, I will not take the time to explain the whole
dialect of regex, nor of Ruby's implementation of it.  There are better resources than me.  I _presume_ that
you do understand Ruby's regex already.

Morphology is stored in an array of objects.  When applying morphology you need the `-m` flag after your
rule file.  These rules are applied in order, so do keep that in mind.

When you generate your words, be certain to split the syllables with a dash in your rules.

A morphology rule is as follows:

    /\-s([^aeiouptc])/ > "-\1"

This rule turns any second or following syllable that begins with an S followed by anything but one of a few
letters, that S gets removed.  The replacement, the "-\1" matches the capture shown in the regex to its left.

### Shorthand Groups

Sometimes you want the transformation to match a named letter pattern.  EG, rather than typing out all the
letters in that rule you can use either of these two short hand expressions:

    V: a e i o u
    
    /(|V)/ > "s\1"   # => /(a|e|i|o|u)/
    /([&V])/ > "s\1" # => /([aeiou])/

### Real Application

See the "alvish.txt" rule file to see some real world application of the morphology rules. Alvish is [Jeffery
Hennings][alvish] brainchild, which I used as a testcase for creating this feature.

    # Alvish is (C) 1995 by Jeffery Henning
    # Taken from: http://www.langmaker.com/ml0108b.htm
    # 
    # Used w/o permission as an example of new features for werd.rb
    # such as optional groups and morphological simulations.

    # consonants
    A: p b f v t d c g y w th h m l n r s sp st sc
    B: p b f v t d c g y w th h s sp st sc
    C: m l n r
    D: p b f v t d c g y w th h m l n r s
    # vowels
    V: i e a u o
    # word patterns
    W: (A)V(D) (A)V(C)-(B)V(C)-(B)V(D)

    # derivations to "Contemporary Alvish":
    /ti/ > "thi"
    /a\-i/ > "i-a"
    /s\-/ > "-s"
    /\-s([^aeiouptc])/ > "-\1"
    /([td])[aeoiu](|A)$/ > "\1"
    /m([td])$/ > "n\1"
    /^[aeiou]([mlnrs][aeiou])/ > "\1"


  [cpound]: http://www.ruf.rice.edu/~pound/#werd
  [parslet]: http://kschiess.github.com/parslet/index.html
  [markr]: http://www.zompist.com/
  [alvish]: http://www.langmaker.com/ml0108b.htm