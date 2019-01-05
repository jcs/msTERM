; vim:syntax=z8a:ts=8
;
; crt0
; msTERM
;
; Copyright (c) 2019 joshua stein <jcs@jcs.org>
;
; Permission to use, copy, modify, and distribute this software for any
; purpose with or without fee is hereby granted, provided that the above
; copyright notice and this permission notice appear in all copies.
;
; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
; OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;

        .module crt0

	.include "mailstation.inc"
	.globl	_main
	.globl	patch_isr
	.globl	_lptrecv

	.area	_HEADER (ABS)

	; when running as a program from dataflash
	; be sure to change --code-loc parameter in Makefile to 0x4100
	;.org 	0x4000

	; when running from loader
	.org 	0x8000

	jp	boot

	.dw	(icons)
	.dw	(caption)
	.dw	(dunno)

dunno:
	.db	#0
xpos:
	.dw	#0
ypos:
	.dw	#0
caption:
	.dw	#0x0001			; ?
	.dw	(endcap - caption - 6)	; number of chars
	.dw	#0x0006			; offset to first char
	.ascii	"msTERM"		; the caption string
endcap:

icons:
	.dw	(icon2 - icon1)		; size of icon1
	.dw	(icon1 - icons)		; offset to icon1
	.dw	(iconend - icon2)	; size of icon2
	.dw	(icon2 - icons)		; offset to icon2

icon1:
	.dw	#0x0022			; icon width (34, 5 bytes per row)
	.db	#0x22			; icon height (34)

	; icon bitmap, low-order bit displays on the LEFT of each byte!)
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0x00,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x00,#0x55,#0x55, #0xaa,#0xaa,#0x00,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x00,#0x55,#0x55, #0xaa,#0xaa,#0x00,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x00,#0x55,#0x55, #0xaa,#0xaa,#0x00,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x00,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa
	.db	#0x55,#0x55,#0x55,#0x55,#0x55, #0xaa,#0xaa,#0xaa,#0xaa,#0xaa

icon2:
	; not used
	.dw	#0x0000			; width
	.db	#0x00			; height
iconend:

boot:
	; preserve old slot4000 for later
	ld	a, (#06)
	ld	(startup_slot4000device), a
	ld	a, (#05)
	ld	(startup_slot4000page), a

	call    gsinit			; initialize global variables
	call	patch_isr		; install new ISR
	call	_main			; main c code
	jp	_exit

	; ordering of segments for the linker
	.area	_HOME

	.area	_CODE

        .area   _GSINIT

gsinit::

        .area   _GSFINAL

gsfinal::
	ret

	; variables
        .area   _BSS

startup_slot4000device:
	.ds	1
startup_slot4000page:
	.ds	1

_debug0::
	.db	#0
_debug1::
	.db	#0
_debug2::
	.db	#0
_debug3::
	.db	#0
_debug4::
	.db	#0

	.area	_DATA

        .area   _HEAP

        .area   _CODE

; exit handler, jump back to loader
_exit::
	ld	a, (startup_slot4000device)
	ld	(#06), a
	ld	a, (startup_slot4000page)
	ld	(#05), a
	jp	0x4000

_powerdown_mode::
	call	#0x0a6b			; firmware powerdownmode function

_reboot::
	jp	0x0000

; new_mail(unsigned char on)
; toggles 'new mail' light
_new_mail::
	di
	push	ix
	ld	ix, #0
	add	ix, sp
	push	hl
	push	af
	ld	a, 4(ix)
	cp	#0
	jr	z, light_off
light_on:
	ld	a, (p2shadow)
	set	4, a
	jr	write_p2
light_off:
	ld	a, (p2shadow)
	res	4, a
write_p2:
	ld	(hl), a
	out	(#0x02), a		; write p2shadow to port2
	pop	af
	pop	hl
	pop	ix
	ei
	ret

; delay(unsigned int millis)
; call mailstation function that delays (stack) milliseconds
_delay::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	af
	push	bc
	push	hl
	ld	l, 4(ix)
	ld	h, 5(ix)
	push	hl
	call	#0x0a5c
	pop	hl
	pop	hl
	pop	bc
	pop	af
	pop	ix
	ret

; void lcd_sleep(void)
; turn the LCD off
_lcd_sleep::
	di
	ld	a, (p2shadow)
	and	#0b01111111		; LCD_ON - turn port2 bit 7 off
	ld	(p2shadow), a
	out	(#0x02), a		; write p2shadow to port2
	ei
	ret


; void lcd_wake(void)
; turn the LCD on
_lcd_wake::
	di
	ld	a, (p2shadow)
	or	#0b10000000		; LCD_ON - turn port2 bit 7 on
	ld	(p2shadow), a
	out	(#0x02), a		; write p2shadow to port2
	ei
	ret


; 8-bit multiplication
; de * a = hl
mult8::
	ld	b, #8
	ld	hl, #0
mult8_loop:
	add	hl, hl
	rlca
	jr	nc, mult8_noadd
	add	hl, de
mult8_noadd:
	djnz	mult8_loop
mult8_out:
	ret

; 16-bit multiplication
; bc * de = hl
mult16:
	ld	a, b
	ld	b, #16
	ld	hl, #0
mult16_loop:
	add	hl, hl
	sla	c
	rla
	jr	nc, mult16_noadd
	add	hl, de
mult16_noadd:
	djnz	mult16_loop
	ret


; 8-bit division
; divide e by c, store result in a and remainder in b
div8:
	xor	a
	ld	b, #8
div8_loop:
	rl	e
	rla
	sub	c
	jr	nc, div8_noadd
	add	a, c
div8_noadd:
	djnz	div8_loop
	ld	b,a
	ld	a,e
	rla
	cpl
	ret

; 16-bit division
; divide bc by de, store result in bc, remainder in hl
div16:
	ld	hl, #0
	ld	a, b
	ld	b, #8
div16_loop1:
	rla
	adc	hl, hl
	sbc	hl, de
	jr	nc, div16_noadd1
	add	hl, de
div16_noadd1:
	djnz	div16_loop1
	rla
	cpl
	ld	b, a
	ld	a, c
	ld	c, b
	ld	b, #8
div16_loop2:
	rla
	adc	hl, hl
	sbc	hl, de
	jr	nc, div16_noadd2
	add	hl, de
div16_noadd2:
	djnz	div16_loop2
	rla
	cpl
	ld	b, c
	ld	c, a
	ret
