; vim:syntax=z8a:ts=8
;
; msTERM
; settings routines manipulating dataflash
; https://github.com/jcs/mailstation-tools/blob/master/docs/flash-28SF040.pdf
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

	.module settings

	.include "mailstation.inc"

	.equ	SDP_LOCK,	#SLOT_ADDR + 0x040a
	.equ	SDP_UNLOCK,	#SLOT_ADDR + 0x041a

	.equ	settings_ident_0,	'j'
	.equ	settings_ident_1,	'c'
	.equ	settings_ident_2,	's'

	.area	_DATA
settings_begin:
settings_ident:
	.db	#settings_ident_0
	.db	#settings_ident_1
	.db	#settings_ident_2
_setting_modem_speed:
	.dw	#MODEM_DEFAULT_SPEED
_setting_modem_quiet:
	.db	#0
settings_end:

	.area	_CODE

; void settings_read(void)
_settings_read::
	push	bc
	push	de
	push	hl
	in	a, (#SLOT_DEVICE)	; store device and page
	ld	h, a
	in	a, (#SLOT_PAGE)
	ld	l, a
	push	hl
	ld	a, #DEVICE_DATAFLASH	; slot 4 device = dataflash
	out	(#SLOT_DEVICE), a
	ld	a, #settings_page
	out	(#SLOT_PAGE), a
	ld	hl, #SLOT_ADDR + (settings_sector * 256)
	push	hl
	ld	a, (hl)
	cp	#settings_ident_0	; verify that the first 3 bytes are
	jr	nz, skip_loading	; our ident characters before loading
	inc	hl
	ld	a, (hl)
	cp	#settings_ident_1
	jr	nz, skip_loading
	inc	hl
	ld	a, (hl)
	cp	#settings_ident_2
	jr	nz, skip_loading
	inc	hl
	ld	bc, #settings_end - settings_begin
	ld	de, #settings_begin
	pop	hl
	ldir				; ld (de), (hl), bc-- until bc == 0
	push	hl
skip_loading:
	pop	hl
	pop	hl
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	a, l
	out	(#SLOT_PAGE), a
	pop	hl
	pop	de
	pop	bc
	ret

sdp:
	ld	a, (#SLOT_ADDR + 0x1823) ; 28SF040 Software Data Protection
	ld	a, (#SLOT_ADDR + 0x1820)
	ld	a, (#SLOT_ADDR + 0x1822)
	ld	a, (#SLOT_ADDR + 0x0418)
	ld	a, (#SLOT_ADDR + 0x041b)
	ld	a, (#SLOT_ADDR + 0x0419)
	ret
	; caller needs to read final SDP_LOCK or SDP_UNLOCK address

; void settings_write(void)
_settings_write::
	push	bc
	push	de
	push	hl
	in	a, (#SLOT_DEVICE)	; store device and page
	ld	h, a
	in	a, (#SLOT_PAGE)
	ld	l, a
	push	hl
	ld	a, #DEVICE_DATAFLASH	; slot 4 device = dataflash
	out	(#SLOT_DEVICE), a
	xor	a
	out	(#SLOT_PAGE), a		; slot 4 page = 0
	call	sdp
	ld	a, (#SDP_UNLOCK)
	ld	a, #settings_page
	out	(#SLOT_PAGE), a
	ld	hl, #SLOT_ADDR + (settings_sector * 256)
sector_erase:
	ld	(hl), #0x20		; 28SF040 Sector-Erase Setup
	ld	(hl), #0xd0		; 28SF040 Execute
sector_erase_wait:
	ld	a, (hl)			; wait until End-of-Write
	ld	b, a
	ld	a, (hl)
	cp	b
	jr	nz, sector_erase_wait
dump_setting_bytes:
	ld	de, #settings_begin
	ld	b, #settings_end - settings_begin
byte_program_loop:
	ld	a, (de)
	ld	c, a
	ld	(hl), #0x10		; 28SF040 Byte-Program Setup
	ld	(hl), a			; 28SF040 Execute
byte_program:
	ld	a, (hl)
	ld	c, a
	ld	a, (hl)			; End-of-Write by reading it
	cp	c
	jr	nz, byte_program	; read until writing succeeds
	inc	hl
	inc	de
	djnz	byte_program_loop
flash_lock:
	xor	a			; slot page = 0
	out	(#SLOT_PAGE), a
	call	sdp
	ld	a, (#SDP_LOCK)
	pop	hl
	ld	a, h
	out	(#SLOT_DEVICE), a
	ld	a, l
	out	(#SLOT_PAGE), a
	pop	hl
	pop	de
	pop	bc
	ret
