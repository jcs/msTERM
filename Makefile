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

ASZ80	?= sdasz80 -l -ff
SDCC	?= sdcc -mz80

SRCDIR	?= ${.CURDIR}

OBJ	?= obj/

all: msterm.bin

clean:
	rm -f *.{map,bin,ihx,lst,rel,sym,lk,noi}

# assembly

crt0.rel: crt0.s
	$(ASZ80) -o ${.TARGET} $>

isr.rel: isr.s
	$(ASZ80) -o ${.TARGET} $>

putchar.rel: putchar.s $(SRCDIR)/font/spleen-5x8.inc
	$(ASZ80) -o ${.TARGET} $(SRCDIR)/putchar.s

getchar.rel: getchar.s
	$(ASZ80) -o ${.TARGET} $>

lpt.rel: lpt.s
	$(ASZ80) -o ${.TARGET} $>

modem.rel: modem.s
	$(ASZ80) -o ${.TARGET} $>

settings.rel: settings.s
	$(ASZ80) -o ${.TARGET} $>

# c code

csi.rel: csi.c
	$(SDCC) -c ${.TARGET} $>

mailstation.rel: mailstation.c
	$(SDCC) -c ${.TARGET} $>

mslib.rel: mslib.c
	$(SDCC) -c ${.TARGET} $>

msterm.rel: msterm.c
	$(SDCC) -c ${.TARGET} $>

# generated code

font/spleen-5x8.inc: font/spleen-5x8.hex
	ruby $(SRCDIR)/tools/hexfont2inc.rb $> > $(SRCDIR)/${.TARGET}

# code-loc must be far enough to hold _HEADER code in crt0
msterm.ihx: crt0.rel isr.rel putchar.rel getchar.rel lpt.rel mailstation.rel \
modem.rel msterm.rel mslib.rel csi.rel settings.rel
	$(SDCC) --no-std-crt0 --code-loc 0x4100 --data-loc 0x0000 -o ${.TARGET} $>

msterm.bin: msterm.ihx
	objcopy -Iihex -Obinary $> $@
	@if [ `stat -f '%z' ${.TARGET}` -gt 16384 ]; then \
		echo "${.TARGET} overflows a dataflash page, must be <= 16384"; \
		exit 1; \
	fi

disasm: msterm.bin
	z80dasm -al -g 0x4000 $> > msterm.dasm

upload: all
	sudo ../../mailstation-tools/obj/sendload -p 0x4000 msterm.bin
