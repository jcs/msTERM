; vim:syntax=z8a:ts=8
;
; msTERM
; getchar and other keyboard routines
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

	.module	getchar

	.include "mailstation.inc"
	.globl	_lptrecv

	.area _DATA

	; scancode_table holds three tables of ascii characters which
	; '_getchar' uses to determine which character to return, depending on
	; the scancode pressed and the state of the shift and caps lock keys.
	.include "scancodes.inc"

keyboardbuffer:
	.ds	2			; scancode buffer for _getchar
capslock:
	.db	#0

	.area _CODE

; unsigned char peekkey(void)
; check for a scancode using the firmware, then look it up in the scancode
; table (respecting the shift key and caps lock as control) and return the
; ascii value of the key in the l register
_peekkey::
	ld	de, #keyboardbuffer
	push	de
	call	get_keycode_from_buffer
	pop	de
	ld	a, (keyboardbuffer)	; check for caps lock first
	cp	#0x60
	jr	z, is_caps_lock
	jr	not_caps_lock
is_caps_lock:
	ld	a, (keyboardbuffer + 1)	; check flags
	bit	0, a			; set=pressed, reset=released
	jp	nz, caps_down
	ld	a, #0			; caps lock released
	ld	(capslock), a
	jr	nokey
caps_down:
	ld	a, #1
	ld	(capslock), a
	jr	nokey
not_caps_lock:
	ld	a, (keyboardbuffer + 1)	; check flags
	bit	0, a			; set=pressed, reset=released
	jp	z, nokey		; key was released, bail
	bit	6, a			; when set, shift was held down
	jr	z, lowercase
capital:
	ld	hl, #scancode_table_uppercase
	jr	char_offset
lowercase:
	ld	a, (capslock)
	cp	#1
	jr	z, as_control
	ld	hl, #scancode_table
	jr	char_offset
as_control:
	ld	hl, #scancode_table_control
	jr	char_offset
char_offset:
	push	hl
	ld	hl, #50
	push	hl
	call	_delay
	pop	hl
	pop	hl
	ld	a, (keyboardbuffer)
	ld	b, #0
	ld	c, a
	add	hl, bc
	ld	a, (hl)
	ld	h, #0
	ld	l, a
	ret
nokey:
	ld	h, #0
	ld	l, #0
	ret


; unsigned char getkey(void)
; peekkey() but loops until a key is available
_getkey::
	call	_peekkey
	ld	a, l
	cp	#0
	jp	z, _getkey
	ret


; int getchar(void)
; uses _getkey and filters out non-printables, returns in l register
_getchar::
	call	_getkey
	ld	a, l
	cp	a, #META_KEY_BEGIN
	jr	nc, _getchar		; a >=
	ret


; int getkeyorlpt(void)
; alternate calls to peekkey() and lptrecv() to get a byte from whichever
; comes first
; h=1 is for keyboard input, h=2 is for lpt input, h=0 for nothing
_getkeyorlpt::
	call	_peekkey2
	ld	a, l
	cp	#0
	jr	z, trylpt
	ld	h, #1
	ret
trylpt:
	call	_lptrecv
	ld	h, #0
	cp	#1
	jr	z, _getkeyorlpt
	ld	h, #2
	ret

; peekkey() with some looping
_peekkey2::
	ld	b, #0xff
peekkey2loop:
	push	bc
	call	_peekkey
	pop	bc
	ld	a, l
	cp	#0
	jr	nz, peekkey2out		; loop until a key is available
	djnz	peekkey2loop
peekkey2out:
	ret
