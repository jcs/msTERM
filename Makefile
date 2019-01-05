#
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

ASZ80	?= sdasz80 -l
SDCC	?= sdcc -mz80

OBJ	?= obj/

all: msterm.bin

clean:
	rm -f *.{map,bin,ihx,lst,rel,sym,lk,noi}

crt0.rel: crt0.s
	$(ASZ80) -o $@ $>

isr.rel: isr.s
	$(ASZ80) -o $@ $>

putchar.rel: putchar.s
	$(ASZ80) -o $@ $>

getchar.rel: getchar.s
	$(ASZ80) -o $@ $>

lpt.rel: lpt.s
	$(ASZ80) -o $@ $>

mailstation.rel: mailstation.c
	$(SDCC) -c $@ $>

modem.rel: modem.s
	$(ASZ80) -o $@ $>

mslib.rel: mslib.c
	$(SDCC) -c $@ $>

msterm.rel: msterm.c
	$(SDCC) -c $@ $>

csi.rel: csi.c
	$(SDCC) -c $@ $>

# code-loc must be far enough to hold _HEADER code in crt0
msterm.ihx: crt0.rel isr.rel putchar.rel getchar.rel lpt.rel mailstation.rel \
modem.rel msterm.rel mslib.rel csi.rel
	$(SDCC) --no-std-crt0 --code-loc 0x8100 --data-loc 0x0000 -o $@ $>

msterm.bin: msterm.ihx
	hex2bin msterm.ihx >/dev/null
	@if [ `stat -f '%z' $@` -gt 16384 ]; then \
		echo "$@ overflows a dataflash page, must be <= 16384"; \
		exit 1; \
	fi

upload: all
	nc -N 192.168.1.129 12345 < msterm.bin
