#!/usr/bin/env ruby
#
# generate_cursorx_lookup
# generate cursorx lookup table using 5 bits for col group and 3 for offset
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

# pixels:    01234567012345670123456801234567012345670123456701234567012345670
# col group: |  19   |  18   |  17   |  16   |   15  |   14  |  13   |  12   |
# font cell: .....11111.....11111.....11111.....11111.....11111.....11111.....

File.open("#{__dir__}/../cursorx_lookup.inc", "w+") do |f|
  f.puts "; AUTOMATICALLY GENERATED FILE - see tools/generate_cursorx_lookup.rb"

  pcol = 0
  64.times do |x|
    col_group = 20 - (pcol / 8) - 1
    off = pcol % 8

    v = sprintf("%05b%03b", col_group, off).to_i(2)

    f.puts "\t.db #0x#{sprintf("%02x", v)}\t\t\t; #{sprintf("%08b", v)} - col group #{col_group}, offset #{off}"

    pcol += 5

    if pcol == 160
      pcol = 0
    end
  end
end
