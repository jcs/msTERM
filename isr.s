; vim:syntax=z8a:ts=8
;
; msTERM
; interrupt service routine
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

        .module isr

	.include "mailstation.inc"
	.globl	_modem_isr

	.equ	isrjump,	#0xf7
	.equ	isrjumptable,	#0xf800

	; we're going to put 0xf7 at 0xf800 - 0xf8ff and then put 0xf8 in the
	; 'i' register.  when an interrupt happens in interrupt mode 2, some
	; garbage byte will be on the bus and form an address 0xf800+garbage.
	; the cpu will then read that address+1 which we know will contain
	; 0xf7f7, and then jump to 0xf7f7, which we contain our own code,
	; which will just be a 'jp isr' to our real ISR

	.area   _CODE

_patch_isr::
	di

	; spray isrjump from isrjumptable to (isrjumptable + 0xff + 1)
	ld	hl, #isrjumptable
	ld	a, #isrjump
	ld	(hl), a
	ld	de, #isrjumptable + 1
	ld	bc, #0x0100
	ldir				; ld (de), (hl); dec bc until 0

	; put our jump at isrjump+isrjump
	ld	h, #isrjump
	ld	l, #isrjump
	ld	(hl), #0xc3		; jp
	inc	hl
	ex	de, hl
	ld	hl, #isr
	ld	a, h
	ld	b, l
	ex	de, hl
	ld	(hl), b			; lower address of isr
	inc	hl
	ld	(hl), a			; upper address of isr

	ld	hl, #isrjumptable
	ld	a, h
	ld	i, a			; interrupts will now be #0xf800 + rand
	im	2			; enable interrupt mode 2

	xor	a			; clear interrupt mask
	set	7, a			; allow interrupt 7 for power button
	;set	6, a			; 6 for modem
	;set	5, a			; 5 for RTC
	set	2, a			; 2 for keyboard
	set	1, a			; 1 for keyboard
	ld	hl, (p3shadow)
	ld	(hl), a			; store this mask in p3shadow
	out	(0x3), a
	ei				; here we go!
	ret

isr:
	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	in	a, (0x3)
	bit	7, a			; power button
	jp	nz, 0x1940
	bit	6, a			; modem
	jp	nz, isr_6
	in	a, (0x3)		; why read again?  factory isr does
	bit	1, a			; keyboard scan, 64hz
	jp	nz, 0x18d4		; use factory handler
	bit	2, a			; keyboard when button pressed
        jp      nz, 0x18e7		; use factory handler
	xor	a			; any other interrupt, just ignore
	out	(0x3), a
	jp	isrout
isr_7:
	ld	hl, (p3shadow)
	ld	a, (hl)
	res	7, a
	out	(0x3), a		; reset interrupt
	ld	a, (hl)
	out	(0x3), a		; set mask back to p3shadow
	call	0x3b19			; default power button handler
	jp	isrout
isr_6:
	ld	hl, (p3shadow)
	ld	a, (hl)
	res	6, a
	out	(0x3), a		; reset interrupt
	ld	a, (hl)
	out	(0x3), a		; set mask back to p3shadow
	call	_modem_isr
	jp	isrout
isrout:
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ei
	reti
