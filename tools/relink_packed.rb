#/usr/bin/env ruby
#
# link, figure out header/code/data sizes, then relink with them packed tightly
# msTERM
#
# Copyright (c) 2021 joshua stein <jcs@jcs.org>
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

def get_size(area)
  File.open("msterm.map", "r") do |f|
    while f && !f.eof?
      line = f.gets
      # _HEADER0                            00000000    000000F9 =         249. bytes (ABS,CON)
      if m = line.match(/^#{area} .* (\d+)\. *bytes/)
        return m[1].to_i
      end
    end
  end

  raise "can't find #{area} in msterm.map"
end

def sdcc(code_start, data_start)
  s = "#{ENV["SDCC"]} --code-loc #{sprintf("0x%04x", code_start)} " +
    "--data-loc #{sprintf("0x%04x", data_start)} -o #{ENV["TARGET"]} " +
    "#{ARGV.join(" ")}"
  puts s
  system(s)
end

base_addr = ENV["BASE_ADDR"].to_i(16)
header_size = 0x1000
code_start = base_addr + header_size
data_start = base_addr + 0x4000

# link once at a large offset data-loc
sdcc(code_start, data_start)

header_size = get_size("_HEADER0")
printf "header:  %d bytes (0x%04x)\n", header_size, header_size

code_size = get_size("_CODE")
printf "code:  %d bytes (0x%04x)\n", code_size, code_size

data_size = get_size("_DATA")
printf "data:   %d bytes (0x%04x)\n", data_size, data_size

printf "total: %d bytes (0x%04x)\n", header_size + code_size + data_size,
  header_size + code_size + data_size

code_start = base_addr + header_size
data_start = code_start + code_size
printf "relinking with base: 0x%04x  code: 0x%04x  data:0x%04x\n",
  base_addr, code_start, data_start

sdcc(code_start, data_start)
