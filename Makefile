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

ASZ80?=		sdasz80 -l -ff
SDCC?=		sdcc -mz80 --opt-code-size

SRCDIR?=	${.CURDIR}

OBJ?=		obj/

# either "flash" or "ram"
LOC?=		ram

.if ${LOC:L} == "flash"
BASE_ADDR=	0x4000
.elif ${LOC:L} == "ram"
BASE_ADDR=	0x8000
.else
.BEGIN:
	@echo 'LOC must be "flash" or "ram"'
	@exit 1
.endif


all: msterm.bin

clean:
	rm -f *.{map,bin,ihx,lst,rel,sym,lk,noi} ${SRCDIR}/logo.h

# assembly

ADDRS_INC=	${SRCDIR}/addrs-${LOC}.inc

crt0.rel: crt0.s
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $>

getchar.rel: getchar.s
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $>

isr.rel: isr.s
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $>

lpt.rel: lpt.s
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $>

modem.rel: modem.s
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $>

putchar.rel: putchar.s $(SRCDIR)/font/spleen-5x8.inc
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $(SRCDIR)/putchar.s

settings.rel: settings.s
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $>

wifi.rel: wifi.s
	$(ASZ80) -o ${.TARGET} ${ADDRS_INC} $>

#csi.rel: csi.s
#	$(ASZ80) -o ${.TARGET} $>
csi.rel: csi.c
	$(SDCC) -c ${.TARGET} $>

$(SRCDIR)/logo.h: logo.ans
	(echo "const char logo[] = {"; xxd -i < $> ; echo "};") > ${.TARGET}

# c code

mslib.rel: mslib.c
	$(SDCC) -c ${.TARGET} $>

main.rel: main.c logo.h
	$(SDCC) -c ${.TARGET} $(SRCDIR)/main.c

# generated code

font/spleen-5x8.inc: font/spleen-5x8.hex
	ruby $(SRCDIR)/tools/hexfont2inc.rb $> > $(SRCDIR)/${.TARGET}

# link

msterm.ihx: crt0.rel isr.rel putchar.rel getchar.rel lpt.rel modem.rel \
main.rel mslib.rel csi.rel settings.rel wifi.rel
	@SDCC="$(SDCC) --no-std-crt0" TARGET="$(.TARGET)" \
		BASE_ADDR="$(BASE_ADDR)" CODE_OFF="$(CODE_OFF)" \
		ruby $(SRCDIR)/tools/relink_packed.rb $>

# convert to binary

msterm.bin: msterm.ihx
	objcopy -Iihex -Obinary $> $@
	@if [ `stat -f '%z' ${.TARGET}` -gt 16384 ]; then \
		ls -l ${.TARGET}; \
		echo "${.TARGET} overflows a ${LOC} page, must be <= 16384; increase DATA_SIZE"; \
		exit 1; \
	fi

# helpers

disasm: msterm.bin
	z80dasm -al -g ${BASE_ADDR} $> > msterm.dasm

upload: all
	../../WiFiStation/host/sendload /dev/cuaU0 msterm.bin
