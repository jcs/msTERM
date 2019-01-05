#!/usr/bin/env ruby
#
# generate_scancodes
# generate scancode lookup tables
# msTERM
#
# Copyright (c) 2019 joshua stein <jcs@jcs.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

META_KEY_BEGIN = 200

KEYS = [
  :MAIN_MENU,
  :BACK,
  :PRINT,
  :F1,
  :F2,
  :F3,
  :F4,
  :F5,
  :POWER,
  :SIZE,
  :SPELLING,
  :EMAIL,
  :PAGE_UP,
  :PAGE_DOWN,
  :CAPS_LOCK,
  :LEFT_SHIFT,
  :RIGHT_SHIFT,
  :FN,
  :UP,
  :DOWN,
  :LEFT,
  :RIGHT,
]

META_KEY_NONE = 255

UPPERCASES = {
  "`" => "~",
  "1" => "!",
  "2" => "@",
  "3" => "#",
  "4" => "$",
  "5" => "%",
  "6" => "^",
  "7" => "&",
  "8" => "*",
  "9" => "(",
  "0" => ")",
  "-" => "_",
  "=" => "+",
  "\\" => "|",
  "[" => "{",
  "]" => "}",
  ";" => ":",
  "'" => "\"",
  "," => "<",
  "." => ">",
  "/" => "?",
}

CONTROLS = {
  "a" => 1,
  "b" => 2,
  "c" => 3,
  "d" => 4,
  "e" => 5,
  "f" => 6,
  "g" => 7,
  "h" => 8,
  "i" => 9,
  "j" => 10,
  "k" => 11,
  "l" => 12,
  "m" => 13,
  "n" => 14,
  "o" => 15,
  "p" => 16,
  "q" => 17,
  "r" => 18,
  "s" => 19,
  "t" => 20,
  "u" => 21,
  "v" => 22,
  "w" => 23,
  "x" => 24,
  "y" => 25,
  "z" => 26,
  "3" => 27,
  "[" => 27,
  "4" => 28,
  "\\" => 28,
  "5" => 29,
  "]" => 29,
  "6" => 30,
  "7" => 31,
  "-" => 31,
  "/" => 31,
  "8" => 127,
}

SCANCODES = {
    0 => :MAIN_MENU,
    1 => :BACK,
    2 => :PRINT,
    3 => :F1,
    4 => :F2,
    5 => :F3,
    6 => :F4,
    7 => :F5,
   15 => :POWER,
   19 => "@",
   20 => :SIZE,
   21 => :SPELLING,
   22 => :EMAIL,
   23 => :PAGE_UP,
   32 => "`",
   33 => "1",
   34 => "2",
   35 => "3",
   36 => "4",
   37 => "5",
   38 => "6",
   39 => "7",
   48 => "8",
   49 => "9",
   50 => "0",
   51 => "-",
   52 => "=",
   53 => "\b", # backspace
   54 => "\\",
   55 => :PAGE_DOWN,
   64 => "\t",
   65 => "q",
   66 => "w",
   67 => "e",
   68 => "r",
   69 => "t",
   70 => "y",
   71 => "u",
   80 => "i",
   81 => "o",
   82 => "p",
   83 => "[",
   84 => "]",
   85 => ";",
   86 => "'",
   87 => "\n",
   96 => :CAPS_LOCK,
   97 => "a",
   98 => "s",
   99 => "d",
  100 => "f",
  101 => "g",
  102 => "h",
  103 => "j",
  112 => "k",
  113 => "l",
  114 => ",",
  115 => ".",
  116 => "/",
  117 => :UP,
  118 => :DOWN,
  119 => :RIGHT,
  128 => :LEFT_SHIFT,
  129 => "z",
  130 => "x",
  131 => "c",
  132 => "v",
  133 => "b",
  134 => "n",
  135 => "m",
  144 => :FN,
  147 => " ",
  150 => :RIGHT_SHIFT,
  151 => :LEFT,
}

File.open("#{__dir__}/../scancodes.inc", "w+") do |scf|
  scf.puts "; AUTOMATICALLY GENERATED FILE - see tools/generate_scancodes.rb"
  scf.puts "\t.equ\tMETA_KEY_BEGIN,\t#0d#{sprintf("%03d", META_KEY_BEGIN)}"
  scf.puts "\t.equ\tMETA_KEY_NONE,\t#0d#{sprintf("%03d", META_KEY_NONE)}"
  scf.puts

  3.times do |x|
    if x == 0
      scf.puts "scancode_table:"
    elsif x == 1
      scf.puts
      scf.puts "scancode_table_uppercase:"
    elsif x == 2
      scf.puts
      scf.puts "scancode_table_control:"
    end

    (0 .. SCANCODES.keys.last).each do |sc|
      if k = SCANCODES[sc]
        origk = k
        if k.is_a?(Symbol)
          k = META_KEY_BEGIN + KEYS.index(k)
        elsif k.is_a?(String)
          k = k.ord
        end
        raise if !k

        if x == 1
          if u = UPPERCASES[origk]
            k = u.ord
            origk = u
          elsif ("a" .. "z").include?(origk)
            k = origk.upcase.ord
            origk = origk.upcase
          end
        elsif x == 2
          if u = CONTROLS[origk]
            k = u
            origk = u
          end
        end

        scf.puts "\t.db #0d#{sprintf("%03d", k)}\t\t; #{origk.inspect}"
      else
        scf.puts "\t.db #0d#{sprintf("%03d", META_KEY_NONE)}"
      end
    end
  end
end

File.open("#{__dir__}/../meta_keys.h", "w+") do |mkh|
  mkh.puts "/* AUTOMATICALLY GENERATED FILE - see tools/generate_scancodes.rb */"
  mkh.puts "#define\tMETA_KEY_BEGIN\t#{META_KEY_BEGIN}"

  KEYS.each_with_index do |k,x|
    mkh.puts "#define\tKEY_#{k}\t#{k.length < 3 ? "\t" : ""}#{META_KEY_BEGIN + x}"
  end

  mkh.puts
  mkh.puts "#define\tMETA_KEY_NONE\t#{META_KEY_NONE}"
end
