; vim:syntax=z8a:ts=8
;
; msTERM
; modem routines for Rockwell RCV336DPFSP
; https://github.com/jcs/mailstation-tools/blob/master/docs/modem-RCV336DPFSP.pdf
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
_modem_flowing::
	.db	#0

	.area	_CODE

_modem_isr::
	push	af
	push	hl
	push	bc
	ld	l, #1
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
	jr	z, modem_isr_out
	ld	b, #16			; read 16 bytes at a time
modem_read_loop:
	push	bc
	push	hl
	call	_modem_read
	ld	b, l
	pop	hl
	ld	hl, #_modem_buf
	ld	a, (_modem_buf_pos)
	ld	l, a			; 0xf600 + (modembufpos)
	ld	(hl), b
	inc	a
	ld	(_modem_buf_pos), a
	pop	bc
	djnz	check_for_more_bytes
	jr	modem_isr_out
check_for_more_bytes:
	call	_modem_lsr
	bit	0, l
	jr	nz, modem_read_loop
modem_isr_out:
	call	_modem_msr		; modem status update
	ld	a, l
	ld	(_modem_curmsr), a
	pop	bc
	pop	hl
	pop	af
	ret


; void modem_init(void)
; most of this is from 0x33f7 in v2.54 firmware
_modem_init::
	push	bc
	push	hl
	ld	a, #0
	ld	(_modem_buf_pos), a
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
	in	a, (#SLOT_DEVICE)	; store old slot device
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
	ld	hl, #100
	push	hl
	call	_delay			; delay 100ms
	pop	hl
	ld	a, #0x01
	out	(#0x26), a		; turn port 26 on
	ld	hl, #2000
	push	hl
	call	_delay			; delay 2 seconds
	pop	hl
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a	; switch slot device to modem
	ld	a, #0b11000111		; 14 byte FIFO
	ld	(#SLOT_ADDR + 0x2), a	; FCR = enable FIFO
	ld	a, #0b10000011
	ld	(#SLOT_ADDR + 0x3), a	; LCR = DLAB=1, 8n1
	xor	a
	ld	(#SLOT_ADDR + 0x1), a	; DLM = 0
determine_dlab:
dlab_57600:
	ld	hl, (_setting_modem_speed)
	ld	de, #57600
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_38400
	ld	a, #0x2 		; DLL = 2, baud rate = 57600
	jp	set_dlab
dlab_38400:
	ld	hl, (_setting_modem_speed)
	ld	de, #38400
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_28800
	ld	a, #0x3 		; DLL = 3, baud rate = 38400
	jr	set_dlab
dlab_28800:
	ld	hl, (_setting_modem_speed)
	ld	de, #28800
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_19200
	ld	a, #0x4 		; DLL = 4, baud rate = 28800
	jr	set_dlab
dlab_19200:
	ld	hl, (_setting_modem_speed)
	ld	de, #19200
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_9600
	ld	a, #0x6 		; DLL = 6, baud rate = 19200
	jr	set_dlab
dlab_9600:
	ld	hl, (_setting_modem_speed)
	ld	de, #9600
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_4800
	ld	a, #0x0c 		; DLL = 0x0c, baud rate = 9600
	jr	set_dlab
dlab_4800:
	ld	hl, (_setting_modem_speed)
	ld	de, #4800
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_2400
	ld	a, #0x18 		; DLL = 0x18, baud rate = 4800
	jr	set_dlab
dlab_2400:
	ld	hl, (_setting_modem_speed)
	ld	de, #2400
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_1200
	ld	a, #0x30 		; DLL = 0x30, baud rate = 2400
	jr	set_dlab
dlab_1200:
	ld	hl, (_setting_modem_speed)
	ld	de, #1200
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_300
	ld	a, #0x60 		; DLL = 0x60, baud rate = 1200
	jr	set_dlab
dlab_300:
	ld	hl, (_setting_modem_speed)
	ld	de, #300
	or	a			; reset c
	sbc	hl, de
	add	hl, de
	jr	c, dlab_default
	ld	a, #0x01
	ld	(#SLOT_ADDR + 0x1), a	; DLM = 0x1
	ld	a, #0x80		; DLL = 0x80, baud rate = 300
	jr	set_dlab
dlab_default:
	ld	hl, #MODEM_DEFAULT_SPEED
	ld	(_setting_modem_speed), hl
	jp	determine_dlab		; run through the loop again
set_dlab:
	ld	(#SLOT_ADDR), a		; DLL
	ld	a, #0b00000011
	ld	(#SLOT_ADDR + 0x3), a	; LCR = DLAB=0, 8n1
	ld	a, (#SLOT_ADDR + 0x4)	; read MCR
	or	#0b00001011
	ld	(#SLOT_ADDR + 0x4), a	; MCR = DTR, RTS, HINT
	ld	b, #0x01
	ld	c, #0x06
;	call	0x0a2f			; jp 0x1afb, do something with port 3
;	call	0x33ca			; init modem vars, activate interrupts
	ld	a, #0b00001001		; IER = EDSSI, ERBFI
	ld	(#SLOT_ADDR + 0x1), a
	ld	a, (#SLOT_ADDR + 0x6)
	ld	(_modem_curmsr), a	; read and store MSR
	pop	af
	out	(#SLOT_DEVICE), a	; restore old slot device
	pop	hl
	pop	bc
	ret


; char modem_read(void)
; return a byte in hl from the modem FIFO, from 0x3328 in v2.54 firmware
_modem_read::
	; use	hl
	ld	hl, #1
	push	hl
	call	_new_mail
	pop	hl
	in	a, (#SLOT_ADDR)		; save old slot device
	ld	h, a			; into h
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a	; slot device = modem
	ld	a, (#SLOT_ADDR)		; read byte from modem
	ld	l, a			; into l
	ld	a, h
	out	(#SLOT_DEVICE), a	; set old slot device
	ld	h, #0x00
	push	hl
	ld	hl, #0
	push	hl
	call	_new_mail
	pop	hl
	pop	hl
	ret				; return hl


; void modem_write(char c)
; write a byte to the modem TX FIFO, from 0x33b6 in v2.54 firmware
_modem_write::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	hl
	ld	hl, #1
	push	hl
	call	_new_mail
	pop	hl
	ld	a, 4(ix)
	ld	l, a
	in	a, (#SLOT_DEVICE)
	ld	h, a
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a
	ld	a, l
	ld	(#SLOT_ADDR), a
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	hl, #0
	push	hl
	call	_new_mail
	pop	hl
	pop	hl
	pop	ix
	ret


; int modem_ier(void)
; return modem IER register in hl, from 0x3339 in v2.54 firmware
_modem_ier::
	in	a, (#SLOT_DEVICE)
	ld	h, a
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a
	ld	a, (#SLOT_ADDR + 0x1)	; read modem IER
	ld	l, a
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	h, #0x0
	ret


; int modem_iir(void)
; return modem IIR register in hl, from 0x334a in v2.54 firmware
_modem_iir::
	in	a, (#SLOT_DEVICE)
	ld	h, a
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a
	ld	a, (#SLOT_ADDR + 0x2)	; read modem IIR
	ld	l, a
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	h, #0x0
	ret


; int modem_lcr(void)
; return modem LCR register in hl
_modem_lcr::
	in	a, (#SLOT_DEVICE)
	ld	h, a
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a
	ld	a, (#SLOT_ADDR + 0x3)	; read LCR
	ld	l, a
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	h, #0x00
	ret


; int modem_lsr(void)
; return modem LSR register in hl
_modem_lsr::
	in	a, (#SLOT_DEVICE)
	ld	h, a
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a
	ld	a, (#SLOT_ADDR + 0x5)	; read LSR
	ld	l, a
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	h, #0x00
	ret


; int modem_msr(void)
; return modem MSR register in hl
_modem_msr::
	in	a, (#SLOT_DEVICE)
	ld	h, a
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a
	ld	a, (#SLOT_ADDR + 0x6)	; read modem MSR
	ld	(_modem_curmsr), a
	ld	l, a
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	h, #0x0
	ret

; void modem_hangup(void)
; drop DTR to force a hangup
_modem_hangup::
	push	hl
	in	a, (#SLOT_DEVICE)
	ld	h, a
	ld	a, #DEVICE_MODEM
	out	(#SLOT_DEVICE), a
	ld	a, (#SLOT_ADDR + 0x4)	; read modem MCR
	res	0, a			; drop DTR
	ld	(#SLOT_ADDR + 0x4), a
	push	af
	push	hl
	ld	hl, #500
	push	hl
	call	_delay			; sleep 500ms
	pop	hl
	pop	hl
	pop	af
	set	0, a			; restore DTR
	ld	a, (#SLOT_ADDR + 0x6)
	ld	(_modem_curmsr), a
	ld	(#SLOT_ADDR + 0x4), a
	ld	a, (#SLOT_ADDR + 0x6)
	ld	(_modem_curmsr), a
	ld	a, h
	out	(#SLOT_DEVICE), a
	pop	hl
	ret

; void modem_pause(void)
; send XOFF
_modem_pause::
	push	hl
	ld	l, #XOFF
	push	hl
	call	_modem_write
	pop	hl
	pop	hl
	ld	a, #0
	ld	(_modem_flowing), a
	ret

; void modem_unpause(void)
; send XON
_modem_unpause::
	push	hl
	ld	l, #XON
	push	hl
	call	_modem_write
	pop	hl
	pop	hl
	ret
