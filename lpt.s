; vim:syntax=z8a:ts=8
;
; parallel port routines
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

	.module	lpt

	.include "mailstation.inc"

	.equ	CONTROL,	#0x2c
	.equ	DATA,		#0x2d
	.equ	STATUS,		#0x21

	.equ	LPT_BUSY_IN,	#0x40
	.equ	LPT_BUSY_OUT,	#0x08
	.equ	LPT_STROBE_IN,	#0x80
	.equ	LPT_STROBE_OUT,	#0x10
	.equ	LPT_TRIB_MASK,	#0x07
	.equ	LPT_DIB_MASK,	#0x03

	.area   _CODE

; receive a tribble byte from host, return h=1 l=0 on error, else h=0, l=(byte)
lptrecv_tribble:
	push	bc
	ld	hl, #0			; h will contain error, l result
	xor	a
	out	(DATA), a		; drop busy/ack, wait for strobe
	ld	b, #0xff		; try a bunch before bailing
wait_for_strobe:
	in	a, (STATUS)
	and	#LPT_STROBE_IN		; inb(STATUS) & stbin
	jr	nz, got_strobe
	jr	wait_for_strobe
strobe_failed:
	ld	h, #1
	ld	l, #0
	jr	lptrecv_tribble_out
got_strobe:
	in	a, (STATUS)
	sra	a
	sra	a
	sra	a
	and	#LPT_TRIB_MASK		; & tribmask
	ld	l, a
	ld	a, #LPT_BUSY_OUT	; raise busy/ack
	out	(DATA), a
	ld	b, #0xff		; retry 255 times
wait_for_unstrobe:
	in	a, (STATUS)
	and	#LPT_STROBE_IN		; inb(STATUS) & stbin
	jr	z, lptrecv_tribble_out
	jr	wait_for_unstrobe
	; if we never get unstrobe, that's ok
lptrecv_tribble_out:
	ld	a, #LPT_BUSY_OUT	; raise busy/ack
	out	(DATA), a
	pop	bc
	ret


; unsigned char lptrecv(void)
; receive a full byte from host in three parts
; return h=1 l=0 on error, otherwise h=0, l=(byte)
_lptrecv::
	push	bc
	call	lptrecv_tribble
	ld	a, h
	cp	#1
	jr	z, lptrecv_err		; bail early if h has an error
	ld	b, l
	call	lptrecv_tribble
	ld	a, h
	cp	#1
	jr	z, lptrecv_err
	ld	a, l
	sla	a
	sla	a
	sla	a
	add	b
	ld	b, a			; += tribble << 3
	call	lptrecv_tribble
	ld	a, h
	cp	#1
	jr	z, lptrecv_err
	ld	a, l
	and	#LPT_DIB_MASK		; dibmask
	sla	a
	sla	a
	sla	a
	sla	a
	sla	a
	sla	a
	add	b			; += (tribble & dibmask) << 6
	ld	h, #0
	ld	l, a
lptrecv_out:
	pop	bc
	ret
lptrecv_err:
	pop	bc
	ld	hl, #0x0100
	ret


; send a tribble byte in register l to host, return l=0 on success
lptsend_tribble:
	push	bc
	ld	h, #1
	ld	c, #0xff		; 255*255 tries before bailing
wait_for_busy_drop_outer:
	ld	b, #0xff
wait_for_busy_drop:
	in	a, (STATUS)
	and	#LPT_BUSY_IN		; inb(STATUS) & bsyin
	jr	z, got_busy_drop
	djnz	wait_for_busy_drop
	dec	c
	ld	a, c
	cp	#0
	jr	nz, wait_for_busy_drop_outer
busy_drop_failed:
	jr	lptsend_tribble_out
got_busy_drop:
	ld	a, l
	and	#LPT_TRIB_MASK
	or	#LPT_STROBE_OUT
	out	(DATA), a
	ld	c, #0xff		; try 255*255 tries before bailing
wait_for_ack_outer:
	ld	b, #0xff
wait_for_ack:
	in	a, (STATUS)
	and	#LPT_BUSY_IN		; inb(STATUS) & stbin
	jr	nz, lptsend_unstrobe
	djnz	wait_for_ack
	dec	c
	ld	a, c
	cp	#0
	jr	nz, wait_for_ack_outer
	jr	lptsend_tribble_out
lptsend_unstrobe:
	ld	a, #1
	out	(DATA), a
	ld	h, #0			; success
lptsend_tribble_out:
	ld	a, #LPT_BUSY_OUT	; raise busy/ack
	out	(DATA), a
	pop	bc
	ld	l, h			; l=1 error, l=0 success
	ld	h, #0
	ret


; unsigned int lptsend(unsigned char b)
; returns 0 on success
_lptsend::
	push	ix
	ld	ix, #0
	add	ix, sp
	ld	l, 4(ix)		; char to send
	push	hl
	call	lptsend_tribble
	ld	a, l
	pop	hl
	cp	#0
	jr	z, tribble2
	ld	hl, #0x1
	jr	lptsend_error
tribble2:
	push	hl
	sra	l
	sra	l
	sra	l			; b >> 3
	call	lptsend_tribble
	ld	a, l
	pop	hl
	cp	#0
	jr	z, tribble3
	ld	hl, #0x2
	jr	lptsend_error
tribble3:
	sra	l
	sra	l
	sra	l
	sra	l
	sra	l
	sra	l			; b >> 6
	call	lptsend_tribble
	ld	a, l
	cp	#0
	jr	z, lptsend_out
	ld	hl, #0x3
	jr	lptsend_error
lptsend_out:
	ld	hl, #0
	ld	sp, ix
	pop	ix
	ret
lptsend_error:
	ld	sp, ix
	pop	ix
	ret


; send pushed 16-bit as two bytes
_lptsend16::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	hl
	ld	h, #0
	ld	l, 5(ix)
	push	hl
	call	_lptsend
	pop	hl
	ld	l, 4(ix)
	push	hl
	call	_lptsend
	pop	hl
	pop	hl
	ld	sp, ix
	pop	ix
	ret
