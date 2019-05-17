#
# hexfont2inc
# convert a hex-exported bitmap font (like from gbdfed) to an asm include file
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

chars = []
char_size = 0
all_bytes = []

if !ARGV[0]
  puts "usage: #{$0} <hex file converted from bdf>"
  exit 1
end

File.open(ARGV[0], "r") do |f|
  char = 0

  while f && !f.eof?
    line = f.gets

    # 0023:A0E0A0E0A000
    if !(m = line.match(/^(....):(.+)$/))
      raise "unexpected format: #{line.inspect}"
    end

    char = m[1].to_i(16)
    char_size = (m[2].length / 2)

    # A0E0A0E0A000
    # -> [ "A0", "e0", "A0", "e0", "A0", "00", "00" ]
    bytes = m[2].scan(/(..)/).flatten

    # -> [ 0xa0, 0xe0, 0xa0, 0xe0, 0xa0, 0x00, 0x00 ]
    bytes = bytes.map{|c| c.to_i(16) }

    # -> [ 101000000, 11100000, ... ]
    # -> [ [ 1, 0, 1, 0, 0, 0, 0, 0 ], [ 1, 1, 1, 0, 0, 0, 0, 0 ], ... ]
    bytes = bytes.map{|c| sprintf("%08b", c).split(//).map{|z| z.to_i } }

    # -> [ [ 0, 0, 0, 0, 0, 1, 0, 1 ], [ 0, 0, 0, 0, 0, 1, 1, 1 ], ... ]
    bytes = bytes.map{|a| a.reverse }

    # -> [ 0x5, 0x7, ... ]
    bytes = bytes.map{|a| a.join.to_i(2) }

    chars[char] = bytes
  end
end

(0 .. 255).each do |c|
  if chars[c] && chars[c].any?
    print ".db " << chars[c].map{|c| sprintf("#0x%02x", c) }.join(", ")
    if c >= 32 && c <= 126
      print "\t; #{sprintf("%.3d", c)} - #{c.chr}"
    end
    print "\n"
  else
    puts ".db " << char_size.times.map{|c| "#0x00" }.join(", ")
  end
end
