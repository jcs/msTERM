; vim:syntax=z8a:ts=8
;
; modem routines for Rockwell RCV336DPFSP
; https://github.com/jcs/mailstation-tools/blob/master/docs/modem-RCV336DPFSP.pdf
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

	.module modem

	.include "mailstation.inc"
	.globl	_new_mail

	.area	_DATA

	; modem msr
_modem_curmsr::
	.db	#0

	.area	_CODE

_modem_isr::
	push	hl
	ld	l, #1
	push	hl
	call	_new_mail
	pop	hl
	call	_modem_iir		; read IIR to identify interrupt
	bit	#0, l
	jr	nz, modem_isr_out	; no interrupt, how did we get here?
	ld	a, l
	and	#0b00001111		; mask off high 4 bits
	ld	l, a
has_irq:
	and	#0b00000110		; receiver line status, some error
	jr	nz, no_rls
	push	hl
	call	_modem_lsr		; what are we supposed to do with it?  (FCR bit 1?)
	pop	hl
	jr	modem_isr_out
no_rls:
	ld	a, l
	and	#0b00000100		; received data available or timeout
	jr	z, no_rda
modem_read_loop:
	push	hl
	call	_modem_read
	ld	b, l
	pop	hl
	ld	hl, #modem_buf
	ld	a, (modem_buf_pos)
	ld	l, a			; 0xf600 + (modembufpos)
	ld	(hl), b
	inc	a
	ld	(modem_buf_pos), a
	call	_modem_lsr
	bit	0, l
	jr	nz, modem_read_loop
no_rda:
modem_isr_out:
	call	_modem_msr		; modem status update
	ld	a, l
	ld	(_modem_curmsr), a
	pop	hl
	ret


; void modem_init(void)
; most of this is from 0x33f7 in v2.54 firmware
_modem_init::
	push	bc
	push	hl
	ld	a, #0
	ld	(modem_buf_pos), a
	call	0x3dbe			; disable caller id?
	ld	a, (p3shadow)
	res	7, a			; disable caller id interrupt
	ld	(p3shadow),a
	out	(#0x03), a
	in	a, (#0x29)		; XXX what is port 29?
	or	#0x0c
	out	(#0x29), a
	ld	a, (p28shadow)
	set	2, a
	res	3, a
	ld	(p28shadow), a
	out	(#0x28), a		; XXX what is port 28?
	xor	a
	ld	(#0xe63b), a		; no idea what these shadow vars are
	ld	(#0xe63a), a
	ld	(#0xe64d), a
	ld	(#0xe638), a		; but init them all to 0
; l33f8
	ld	a, #0x01
	ld	(#0xe638), a
	in	a, (#0x06)		; store old slot4000device
	push	af
	ld	a, (p2shadow)		; read p2shadow
	res	5, a
	ld	(p2shadow), a		; write p2shadow
	out	(#0x02), a		; also write it to port2
	ld	hl, #300
	push	hl
	call	_delay			; delay 300ms
	pop	hl
	ld	a, #0
	out	(#0x26), a		; turn port 26 off
	ld	hl, #100		; 100
	push	hl
	call	_delay			; delay 100ms
	pop	hl
	ld	a, #0x01
	out	(#0x26), a
	ld	hl, #3000		; 3000
	push	hl
	call	_delay			; delay 3 seconds
	pop	hl
	ld	a, #0x05
	out	(#0x06), a		; switch slot4000device to modem
	ld	a, #0b11000111		; 14 byte trigger
	;ld	a, #0b00000111		; XXX: try 1-byte trigger instead
	ld	(#0x4002), a		; FCR = enable FIFO
;	ld	a, (#0xe62c)		; what variable is at 0xe62c?
;	or	a
;	jr	z, skip_dlab
;	ld	a, #0b10000011
;	ld	(#0x4003), a		; LCR = DLAB=1, 8n1
;	ld	a, #0x6
;	ld	(#0x4000), a		; DLL = 6
;	ld	a, #0
;	ld	(#0x4001), a		; DLM = 0 = divisor 6 = baud rate 19200
;skip_dlab:
	ld	a, #0b00000011
	ld	(#0x4003), a		; LCR = DLAB=0, 8n1
	ld	a, (#0x4004)		; read MCR
	or	#0b00001011
	ld	(#0x4004), a		; MCR = DTR, RTS, HINT
	ld	b, #0x01
	ld	c, #0x06
;	call	0x0a2f			; jp 0x1afb, do something with port 3
;	call	0x33ca			; init modem vars, activate interrupts
	ld	a, #0b00001001		; IER = EDSSI, ERBFI
	ld	(#0x4001), a
	ld	a, (#0x4006)
	ld	(_modem_curmsr), a	; read and store MSR
	pop	af
	out	(#0x06), a		; restore old slot4000device
	pop	hl
	pop	bc
	ret


; char modem_read(void)
; return a byte in hl from the modem FIFO, from 0x3328 in v2.54 firmware
_modem_read::
	; use	hl
	in	a, (0x06)		; save old slot4000device
	ld	h, a			; into h
	ld	a, #0x05
	out	(0x06),a		; slot4000device = modem
	ld	a, (0x4000)		; read byte from modem
	ld	l, a			; into l
	ld	a, h
	out	(0x06), a		; set old slot4000device
	ld	h, #0x00
	ret				; return hl


; void modem_write(char c)
; write a byte to the modem TX FIFO, from 0x33b6 in v2.54 firmware
_modem_write::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	hl
	ld	a, 4(ix)
	ld	l, a
	in	a, (0x06)
	ld	h, a
	ld	a, #0x05
	out	(0x06), a
	ld	a, l
	ld	(0x4000), a
	ld	a, h
	out	(0x06), a
	pop	hl
	pop	ix
	ret


; int modem_ier(void)
; return modem IER register in hl, from 0x3339 in v2.54 firmware
_modem_ier::
	in	a, (0x06)
	ld	h, a
	ld	a, #0x05
	out	(0x06), a
	ld	a, (0x4001)		; read modem IER
	ld	l, a
	ld	a, h
	out	(0x06), a
	ld	h, #0x0
	ret


; int modem_iir(void)
; return modem IIR register in hl, from 0x334a in v2.54 firmware
_modem_iir::
	in	a, (0x06)
	ld	h, a
	ld	a, #0x05
	out	(0x06), a
	ld	a, (0x4002)		; read modem IIR
	ld	l, a
	ld	a, h
	out	(0x06), a
	ld	h, #0x0
	ret


; int modem_lcr(void)
; return modem LCR register in hl
_modem_lcr::
	in	a, (0x06)
	ld	h, a
	ld	a, #0x05
	out	(0x06), a
	ld	a, (0x4003)		; read LCR
	ld	l, a
	ld	a, h
	out	(0x06), a
	ld	h, #0x00
	ret


; int modem_lsr(void)
; return modem LSR register in hl
_modem_lsr::
	in	a, (0x06)
	ld	h, a
	ld	a, #0x05
	out	(0x06), a
	ld	a, (0x4005)		; read LSR
	ld	l, a
	ld	a, h
	out	(0x06), a
	ld	h, #0x00
	ret


; int modem_msr(void)
; return modem MSR register in hl
_modem_msr::
	in	a, (0x06)
	ld	h, a
	ld	a, #0x05
	out	(0x06), a
	ld	a, (0x4006)		; read modem MSR
	ld	l, a
	ld	a, h
	out	(0x06), a
	ld	h, #0x0
	ret

; void modem_hangup(void)
; drop DTR to force a hangup
_modem_hangup::
	push	hl
	in	a, (0x06)
	ld	h, a
	ld	a, #0x05
	out	(0x06), a
	ld	a, (0x4004)		; read modem MCR
	res	0, a			; drop DTR
	ld	(0x4004), a
	push	af
	push	hl
	ld	hl, #500
	push	hl
	call	_delay
	pop	hl
	pop	hl
	pop	af
	set	0, a			; restore DTR
	ld	a, (0x4006)
	ld	(_modem_curmsr), a
	ld	(0x4004), a
	ld	a, (0x4006)
	ld	(_modem_curmsr), a
	ld	a, h
	out	(0x06), a
	pop	hl
	ret
