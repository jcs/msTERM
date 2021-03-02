; vim:syntax=z8a:ts=8
;
; msTERM
; WiFiStation parallel port routines
;
; Copyright (c) 2019-2021 joshua stein <jcs@jcs.org>
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

	.module	wifi

	.include "mailstation.inc"

	.area   _CODE

	.equ	CONTROL_DIR,		#0x0a
	.equ	CONTROL_DIR_OUT,	#0xff
	.equ	CONTROL_DIR_IN,		#0

	.equ	CONTROL_PORT,		#0x9
	.equ	CONTROL_STROBE_BIT,	#0
	.equ	CONTROL_STROBE,		#(1 << CONTROL_STROBE_BIT)
	.equ	CONTROL_LINEFEED_BIT,	#1
	.equ	CONTROL_LINEFEED,	#(1 << CONTROL_LINEFEED_BIT)
	.equ	CONTROL_INIT,		#(1 << 2)
	.equ	CONTROL_SELECT,		#(1 << 3)

	.equ	DATA_DIR,		#0x2c
	.equ	DATA_DIR_OUT,		#0xff
	.equ	DATA_DIR_IN,		#0
	.equ	DATA_PORT,		#0x2d

	.equ	STATUS_PORT,		#0x21
	.equ	STATUS_BUSY,		#(1 << 7)
	.equ	STATUS_ACK,		#(1 << 6)
	.equ	STATUS_PAPEROUT,	#(1 << 5)

; void wifi_init(void);
_wifi_init::
	; lower control lines
	ld	a, #CONTROL_DIR_OUT
	out	(#CONTROL_DIR), a
	xor	a
	out	(#CONTROL_PORT), a
	ret

; at idle, lower all control lines
; writer:				reader:
; raise strobe
;					see high strobe as high busy
;					raise linefeed
; see high linefeed as high ack
; write all data pins
; lower strobe
;					see low strobe as low busy
;					read data
;					lower linefeed
; see lower linefeed as high ack

; int wifi_write(char); -1 on error, 0 on success
_wifi_write::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	bc
	push	de
	ld	c, 4(ix)		; char to send
	ld	a, #DATA_DIR_OUT
	out	(#DATA_DIR), a		; we're sending out
	ld	a, #CONTROL_STROBE
	out	(#CONTROL_PORT), a	; raise strobe
	ld	de, #0xffff
wait_for_ack:
	in	a, (#STATUS_PORT)
	and	#STATUS_ACK		; is ack high?
	jr	nz, got_ack		; yes, break
	dec	de			; no, de--
	ld	a, d
	cp	#0
	jr	nz, wait_for_ack
	ld	a, e
	cp	#0
	jr	nz, wait_for_ack
	jr	abort_send		; de == 0, fail
got_ack:
	ld	a, c
	out	(#DATA_PORT), a		; write data
	xor	a
	out	(#CONTROL_PORT), a	; lower strobe
	ld	de, #0xffff
wait_for_final_ack:
	in	a, (#STATUS_PORT)
	and	#STATUS_ACK		; is ack low?
	jr	z, got_final_ack	; yes, break
	dec	de			; no, de--
	ld	a, d
	cp	#0
	jr	nz, wait_for_final_ack
	ld	a, e
	cp	#0
	jr	nz, wait_for_final_ack
got_final_ack:
	pop	de
	pop	bc
	pop	ix
	ld	hl, #0			; return 0
	ret
abort_send:
	xor	a
	out	(#CONTROL_PORT), a	; lower strobe
	pop	de
	pop	bc
	pop	ix
	ld	hl, #-1			; return -1
	ret


; int wifi_read(void); -1 on nothing read, >= 0 on success returning char
_wifi_read::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	de
	ld	hl, #-1			; return -1 unless we read something
	in	a, (#STATUS_PORT)
	and	#STATUS_BUSY		; is busy high?
	jr	z, recv_done		; no, bail
	ld	a, #DATA_DIR_IN
	out	(#DATA_DIR), a		; we're reading in
	ld	a, #CONTROL_LINEFEED	; raise linefeed
	out	(#CONTROL_PORT), a
	ld	de, #0xffff
wait_for_busy_ack:
	in	a, (#STATUS_PORT)
	and	#STATUS_BUSY		; is busy high?
	jr	z, read_data		; no, break
	dec	de			; no, de--
	ld	a, d
	cp	#0
	jr	nz, wait_for_busy_ack
	ld	a, e
	cp	#0
	jr	nz, wait_for_busy_ack
	jr	recv_done		; de == 0, fail
read_data:
	in	a, (#DATA_PORT)
	ld	h, #0
	ld	l, a
raise_lf:
	xor	a
	out	(#CONTROL_PORT), a	; lower linefeed
recv_done:
	pop	de
	pop	ix
	ret
