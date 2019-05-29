; vim:syntax=z8a:ts=8
;
; msTERM
; putchar
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

        .module	putchar

	.include "mailstation.inc"

	.area	_DATA

	; screen contents (characters) - should be 0xa000 - 0xa3ff
_screenbuf::
	.ds	(LCD_COLS * LCD_ROWS)
_screenbufend::

	; per-character attributes - should be 0xa400 - 0xa7ff
	; see ATTR_* constants
_screenattrs::
	.ds	(LCD_COLS * LCD_ROWS)
_screenattrsend::

font_data::
	.include "font/spleen-5x8.inc"

	; lookup table for putchar
	; left-most 5 bits are col group for lcd_cas
	; last 3 bits are offset into col group
cursorx_lookup_data::
	.include "cursorx_lookup.inc"

	.area   _BSS

_cursorx::				; cursor x position, 0-indexed
	.db	#0
_cursory::				; cursor y position, 0-indexed
	.db	#0
_putchar_sgr::				; current SGR for putchar()
	.db	#0


	.area   _GSINIT

	call	_clear_screen

	.area   _CODE

; void lcd_cas(unsigned char col)
; enable CAS, address the LCD column col (in h), and disable CAS
_lcd_cas::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	de
	ld	a, (p2shadow)
	and	#0b11110111		; CAS(0) - turn port2 bit 3 off
	ld	(p2shadow), a
	out	(#0x02), a		; write p2shadow to port2
	ld	de, #LCD_START
	ld	a, 4(ix)
	ld	(de), a			; write col argument
	ld	a, (p2shadow)
	or	#0b00001000		; CAS(1) - turn port2 bit 3 on
	ld	(p2shadow), a
	out	(#0x02), a
	pop	de
	ld	sp, ix
	pop	ix
	ret


; void clear_screen(void)
_clear_screen::
	di
	push	bc
	push	de
	push	hl
 	in	a, (#06)
 	ld	h, a			; slot4000 device
 	in	a, (#05)
 	ld	l, a			; slot4000 page
	ld	a, #DEVICE_LCD_RIGHT
	out	(#06), a
	push	hl
	call	_clear_lcd_half
	ld	a, #DEVICE_LCD_LEFT
	out	(#06), a
	call	_clear_lcd_half
	pop	hl
	ld	a, h
	out	(#06), a
	ld	a, l
	out	(#05), a
reset_cursor:
	xor	a
	ld	(_cursorx), a
	ld	(_cursory), a
	ld	(_saved_cursorx), a
	ld	(_saved_cursory), a
	ld	(_putchar_sgr), a
zero_screenbuf:
	ld	hl, #_screenbuf
	ld	de, #_screenbuf + 1
	ld	bc, #_screenbufend - _screenbuf
	ld	(hl), #' '
	ldir
zero_screenattrs:
	ld	hl, #_screenattrs
	ld	de, #_screenattrs + 1
	ld	bc, #_screenattrsend - _screenattrs
	ld	(hl), #0
	ldir
clear_screen_out:
	pop	hl
	pop	de
	pop	bc
	ei
	ret


; void clear_lcd_half(void)
; zero out the current LCD module (must already be in slot4000device)
; from v2.54 firmware at 0x2490
_clear_lcd_half::
	push	bc
	push	de
	ld	b, #20			; do 20 columns total
clear_lcd_column:
	ld	h, #0
	ld	a, b
	dec	a			; columns are 0-based
	ld	l, a
	push	hl
	call	_lcd_cas
	pop	hl
	push	bc			; preserve our column counter
	ld	hl, #LCD_START
	ld	(hl), #0		; zero out hl, then copy it to de
	ld	de, #LCD_START + 1	; de will always be the next line
	ld	bc, #128 - 1		; iterate (LCD_HEIGHT - 1) times
	ldir				; ld (de), (hl), bc-- until 0
	pop	bc			; restore column counter
	djnz	clear_lcd_column	; column--, if not zero keep going
clear_done:
	pop	de
	pop	bc
	ret


; void redraw_screen(void)
_redraw_screen::
	push	bc
	push	de
	push	hl
	ld	b, #0
redraw_rows:
	ld	d, b			; store rows in d
	ld	b, #0
redraw_cols:
	push	bc			; XXX figure out what is corrupting
	push	de			; bc and de in stamp_char, these shouldn't be needed
	push	hl
	ld	h, #0			; cols
	ld	l, b
	push	hl
	ld	h, #0			; rows
	ld	l, d
	push	hl
	call	_stamp_char
	pop	hl
	pop	hl
	pop	hl
	pop	de
	pop	bc
redraw_cols_next:
	inc	hl
	inc	b
	ld	a, b
	cp	#LCD_COLS
	jr	nz, redraw_cols
	ld	b, d
	inc	b
	ld	a, b
	cp	#LCD_ROWS
	jr	nz, redraw_rows
redraw_screen_out:
	pop	hl
	pop	de
	pop	bc
	ret


; void scroll_lcd(void)
; scroll entire screen up by FONT_HEIGHT rows, minus statusbar
_scroll_lcd::
	di
	push	bc
	push	de
	push	hl
 	in	a, (#06)
 	ld	h, a			; slot4000 device
 	in	a, (#05)
 	ld	l, a			; slot4000 page
	push	hl
	ld	a, #DEVICE_LCD_LEFT
	out	(#06), a
	call	_scroll_lcd_half
	ld	a, #DEVICE_LCD_RIGHT
	out	(#06), a
	call	_scroll_lcd_half
	pop	hl
	ld	a, h
	out	(#06), a
	ld	a, l
	out	(#05), a
shift_bufs:
	ld	b, #0
screenbuf_shift_loop:
	ld	h, b
	ld	l, #0
	call	screenbuf_offset
	ld	de, #_screenbuf
	add	hl, de			; hl = screenbuf[b * LCD_COLS]
	push	hl
	ld	de, #LCD_COLS
	add	hl, de			; hl += LCD_COLS
	pop	de			; de = screenbuf[b * LCD_COLS]
	push	bc
	ld	bc, #LCD_COLS
	ldir				; ld (de), (hl), de++, hl++, bc--
	pop	bc
	inc	b
	ld	a, b
	cp	#TEXT_ROWS - 1
	jr	nz, screenbuf_shift_loop
screenattrs_shift:
	ld	b, #0
screenattrs_shift_loop:
	ld	h, b
	ld	l, #0
	call	screenbuf_offset
	ld	de, #_screenattrs
	add	hl, de			; hl = screenattrs[b * LCD_COLS]
	push	hl
	ld	de, #LCD_COLS
	add	hl, de
	pop	de
	push	bc
	ld	bc, #LCD_COLS
	ldir
	pop	bc
	inc	b
	ld	a, b
	cp	#TEXT_ROWS - 1
	jr	nz, screenattrs_shift_loop
last_row_zero:
	ld	a, #TEXT_ROWS - 1
	ld	h, a
	ld	l, #0
	call	screenbuf_offset
	ld	de, #_screenbuf
	add	hl, de
	ld	d, #0
	ld	e, #LCD_COLS - 1
	add	hl, de
	ld	b, #LCD_COLS
	ld	a, (_putchar_sgr)
last_row_zero_loop:
	ld	(hl), #' '
	dec	hl
	djnz	last_row_zero_loop
scroll_lcd_out:
	pop	hl
	pop	de
	pop	bc
	ei
	ret


; void scroll_lcd_half(void)
; scroll current LCD module up by FONT_HEIGHT rows, minus statusbar and
; zero out the last line of text (only to the LCD)
_scroll_lcd_half::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	bc
	push	de
	push	hl
	; alloc 2 bytes on the stack for local storage
	push	hl
	ld	a, #LCD_HEIGHT - (FONT_HEIGHT * 2) ; iterations of pixel row moves
scroll_init:
	ld	-1(ix), a		; store iterations
	ld	b, #20 			; do 20 columns total
scroll_lcd_column:
	ld	-2(ix), b		; store new column counter
	ld	a, b
	sub	#1			; columns are 0-based
	ld	h, #0
	ld	l, a
	push	hl
	call	_lcd_cas
	pop	hl
scroll_rows:
	ld	b, #0
	ld	c, -1(ix)		; bc = row counter
	ld	hl, #LCD_START + 8	; start of next line
	ld	de, #LCD_START
	ldir				; ld (de), (hl), bc-- until 0
scroll_zerolast:
	ld	hl, #LCD_START
	ld	d, #0
	ld	e, -1(ix)
	add	hl, de
	ld	b, #FONT_HEIGHT
scroll_zerolastloop:			; 8 times: zero hl, hl++
	ld	(hl), #0
	inc	hl
	djnz	scroll_zerolastloop
	ld	b, -2(ix)
	djnz	scroll_lcd_column	; column--, if not zero keep going
	pop	hl
	pop	de
	pop	bc
	ld	sp, ix
	pop	ix
	ret


; address of screenbuf or screenattrs offset for a row/col in hl, returns in hl
screenbuf_offset:
	push	bc
	push	de
	; uses	hl
	ex	de, hl
	ld	hl, #0
	ld	a, d			; row
	cp	#0
	jr	z, multiply_srow_out	; only add rows if > 0
	ld	bc, #LCD_COLS
multiply_srow:
	add	hl, bc
	dec	a
	cp	#0
	jr	nz, multiply_srow
multiply_srow_out:
	ld	d, #0			; col in e
	add	hl, de			; hl = (row * LCD_COLS) + col
	pop	de
	pop	bc
	ret	; hl


; void stamp_char(unsigned int row, unsigned int col)
; row at 4(ix), col at 6(ix)
_stamp_char::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	bc
	push	de
	push	hl
	ld	hl, #-15		; stack bytes for local storage
	add	hl, sp
	ld	sp, hl
 	in	a, (#06)
 	ld	-3(ix), a		; stack[-3] = slot4000 device
 	in	a, (#05)
 	ld	-4(ix), a		; stack[-4] = slot4000 page
find_char:
	ld	h, 4(ix)
	ld	l, 6(ix)
	call	screenbuf_offset
	push	hl
	ld	de, #_screenbuf
	add	hl, de			; hl = screenbuf[(row * LCD_COLS) + col]
	ld	a, (hl)
	ld	-5(ix), a		; stack[-5] = character to stamp
	pop	hl
	ld	de, #_screenattrs
	add	hl, de			; hl = screenattrs[(row * LCD_COLS) + col]
	ld	a, (hl)
	ld	-6(ix), a		; stack[-6] = character attrs
calc_font_data_base:
	ld	h, #0
	ld	l, -5(ix)		; char
	add	hl, hl			; hl = char * FONT_HEIGHT (8)
	add	hl, hl
	add	hl, hl
 	ld	de, #font_data
	add	hl, de
	ld	-7(ix), l
	ld	-8(ix), h		; stack[-8,-7] = char font data base addr
calc_char_cell_base:
	ld	h, #0
	ld	l, 4(ix)		; row
	add	hl, hl
	add	hl, hl
	add	hl, hl			; hl = row * FONT_HEIGHT (8)
	ld	de, #LCD_START
	add	hl, de			; hl = 4038 + (row * FONT_HEIGHT)
	ld	-9(ix), l
	ld	-10(ix), h		; stack[-10,-9] = lcd char cell base
fetch_from_table:
	ld	a, 6(ix)		; col
	ld	hl, #cursorx_lookup_data
	ld	b, #0
	ld	c, a
	add	hl, bc
	ld	b, (hl)
	ld	a, b
pluck_col_group:
	and	#0b11111000		; upper 5 bits are col group
	srl	a
	srl	a
	srl	a
	ld	-11(ix), a		; stack[-11] = col group
pluck_offset:
	ld	a, b
	and	#0b00000111		; lower 3 bits are offset
	ld	-12(ix), a		; stack[-12] = offset
	ld	-15(ix), #0		; stack[-15] = previous lcd col
	ld	d, #FONT_HEIGHT		; for (row = FONT_HEIGHT; row >= 0; row--)
next_char_row:
	ld	a, d
	dec	a
	ld	h, -8(ix)		; char font data base
	ld	l, -7(ix)
	ld	b, #0
	ld	c, a
	add	hl, bc
	ld	a, (hl)			; font_addr + (char * FONT_HEIGHT) + row
	ld	b, -6(ix)
	bit	#ATTR_BIT_REVERSE, b
	jr	nz, reverse
	bit	#ATTR_BIT_CURSOR, b
	jr	nz, reverse
	jr	not_reverse
reverse:
	cpl				; flip em
	and	#0b00011111		; mask off bits not within FONT_WIDTH
not_reverse:
	ld	-13(ix), a		; stack[-13] = working font data
	ld	a, -6(ix)
	bit	#ATTR_BIT_UNDERLINE, a
	jr	z, not_underline
	ld	a, d
	cp	#FONT_HEIGHT
	jr	nz, not_underline
underline:
	ld	-13(ix), #0xff
not_underline:
	ld	a, 6(ix)		; col
	cp	#LCD_COLS / 2		; assume a char never spans both LCD sides
	jr	nc, rightside
leftside:
	ld	a, #DEVICE_LCD_LEFT
	jr	swap_lcd
rightside:
	ld	a, #DEVICE_LCD_RIGHT
swap_lcd:
	out	(#06), a
	ld	e, #FONT_WIDTH		; for (col = FONT_WIDTH; col > 0; col--)
next_char_col:				; inner loop, each col of each row
	ld	-14(ix), #0b00011111	; font data mask that will get shifted
determine_cas:
	ld	c, #0
	ld	b, -11(ix)		; col group
	ld	a, -12(ix)		; bit offset
	add	#FONT_WIDTH
	sub	e			; if offset+(5-col) is >= 8, advance col
	cp	#LCD_COL_GROUP_WIDTH
	jr	c, skip_advance		; if a >= 8, advance (dec b)
	dec	b
	ld	c, -12(ix)		; bit offset
	ld	a, #LCD_COL_GROUP_WIDTH
	sub	c
	ld	c, a			; c = number of right shifts
skip_advance:
do_lcd_cas:
	ld	a, -15(ix)		; previous lcd cas
	cp	b
	jr	z, prep_right_shift
	ld	h, #0
	ld	l, b
	push	hl
	call	_lcd_cas
	pop	hl
	ld	-15(ix), b		; store lcd col for next round
	; if this character doesn't fit entirely in one lcd column, we need to
	; span two of them and on the left one, shift font data and masks right
	; to remove right-most bits that will be on the next column
prep_right_shift:
	ld	a, c
	cp	#0
	jr	z, prep_left_shift
	ld	b, c
	ld	c, -14(ix)		; matching mask 00011111
	ld	a, -13(ix)		; load font data like 00010101
right_shift:
	srl	a			; shift font data right #b times
	srl	c			; and mask to match
	djnz	right_shift		; -> 10101000
	ld	-14(ix), c
	jr	done_left_shift
prep_left_shift:
	ld	c, -14(ix)		; mask
	ld	a, -12(ix)		; (bit offset) times, shift font data
	cp	#0
	ld	b, a
	ld	a, -13(ix)		; read new font data
	jr	z, done_left_shift
left_shift:
	sla	a
	sla	c
	djnz	left_shift
done_left_shift:
	ld	b, a
	ld	a, c
	cpl
	ld	-14(ix), a		; store inverted mask
	ld	a, b
read_lcd_data:
	ld	h, -10(ix)
	ld	l, -9(ix)
	ld	b, a
	ld	a, d
	dec	a
	ld	c, a
	ld	a, b
	ld	b, #0
	add	hl, bc			; hl = 4038 + (row * FONT_HEIGHT) + row - 1
	ld	b, a			; store new font data
	ld	a, (hl)			; read existing cell data
	and	-14(ix)			; mask off new char cell
	or	b			; combine data into cell
	ld	(hl), a
	dec	e
	jp	nz, next_char_col
	dec	d
	jp	nz, next_char_row
stamp_char_out:
	ld	a, -3(ix)		; restore slot4000device
	out	(#06), a
	ld	a, -4(ix)		; restore slot4000page
	out	(#05), a
	ld	hl, #15			; remove stack bytes
	add	hl, sp
	ld	sp, hl
	pop	hl
	pop	de
	pop	bc
	ld	sp, ix
	pop	ix
	ret


; void uncursor(void)
; remove cursor attribute from old cursor position
_uncursor::
	push	de
	push	hl
	ld	a, (_cursory)
	ld	h, a
	ld	a, (_cursorx)
	ld	l, a
	call	screenbuf_offset
	ld	de, #_screenattrs
	add	hl, de			; screenattrs[(cursory * TEXT_COLS) + cursorx]
	ld	a, (hl)
	res	#ATTR_BIT_CURSOR, a	; &= ~(ATTR_CURSOR)
	ld	(hl), a
	ld	a, (_cursorx)
	ld	l, a
	push	hl
	ld	a, (_cursory)
	ld	l, a
	push	hl
	call	_stamp_char
	pop	hl
	pop	hl
	pop	hl
	pop	de
	ret

; void recursor(void)
; force-set cursor attribute
_recursor::
	push	de
	push	hl
	ld	a, (_cursory)
	ld	h, a
	ld	a, (_cursorx)
	ld	l, a
	call	screenbuf_offset
	ld	de, #_screenattrs
	add	hl, de			; screenattrs[(cursory * TEXT_COLS) + cursorx]
	ld	a, (hl)
	set	#ATTR_BIT_CURSOR, a
	ld	(hl), a
	pop	hl
	pop	de
	ret


; int putchar(int c)
_putchar::
	push	ix
	ld	ix, #0
	add	ix, sp			; char to print is at 4(ix)
	push	de
	push	hl
	call	_uncursor
	ld	a, 4(ix)
	cp	#'\b'			; backspace
	jr	nz, not_backspace
backspace:
	ld	a, (_cursorx)
	cp	#0
	jr	nz, cursorx_not_zero
	ld	a, (_cursory)
	cp	#0
	jp	z, putchar_fastout	; cursorx/y at 0,0, nothing to do
	dec	a
	ld	(_cursory), a		; cursory--
	ld	a, #LCD_COLS - 2
	ld	(_cursorx), a
	jp	putchar_draw_cursor
cursorx_not_zero:
	dec	a
	ld	(_cursorx), a		; cursorx--;
	jp	putchar_draw_cursor
not_backspace:
	cp	#'\r'
	jr	nz, not_cr
	xor	a
	ld	(_cursorx), a		; cursorx = 0
	jr	not_crlf
not_cr:
	cp	#'\n'
	jr	nz, not_crlf
	xor	a
	ld	(_cursorx), a		; cursorx = 0
	ld	a, (_cursory)
	inc	a
	ld	(_cursory), a		; cursory++
not_crlf:
	ld	a, (_cursorx)
	cp	#LCD_COLS
	jr	c, not_longer_text_cols	; cursorx < TEXT_COLS
	xor	a
	ld	(_cursorx), a		; cursorx = 0
	ld	a, (_cursory)
	inc	a
	ld	(_cursory), a
not_longer_text_cols:
	ld	a, (_cursory)
	cp	#TEXT_ROWS
	jr	c, scroll_out
scroll_up_screen:
	call	_scroll_lcd
	xor	a
	ld	(_cursorx), a
	ld	a, #TEXT_ROWS - 1
	ld	(_cursory), a		; cursory = TEXT_ROWS - 1
scroll_out:
	ld	a, 4(ix)
	cp	a, #'\r'
	jr	z, cr_or_lf
	cp	a, #'\n'
	jr	z, cr_or_lf
	jr	store_char_in_buf
cr_or_lf:
	jp	putchar_draw_cursor
store_char_in_buf:
	ld	a, (_cursory)
	ld	h, a
	ld	a, (_cursorx)
	ld	l, a
	call	screenbuf_offset
	push	hl
	ld	de, #_screenbuf
	add	hl, de			; hl = screenbuf[(cursory * LCD_COLS) + cursorx]
	ld	a, 4(ix)
	ld	(hl), a			; store character
	pop	hl
	ld	de, #_screenattrs
	add	hl, de			; hl = screenattrs[(cursory * LCD_COLS) + cursorx]
	ld	a, (_putchar_sgr)
	ld	(hl), a			; = putchar_sgr
	ld	a, (_cursorx)
	ld	l, a
	push	hl
	ld	a, (_cursory)
	ld	l, a
	push	hl
	call	_stamp_char
	pop	hl
	pop	hl
advance_cursorx:
	ld	a, (_cursorx)
	inc	a
	ld	(_cursorx), a
	cp	#LCD_COLS		; if (cursorx >= LCD_COLS)
	jr	c, putchar_draw_cursor
	xor	a
	ld	(_cursorx), a
	ld	a, (_cursory)
	inc	a
	ld	(_cursory), a
check_cursory:
	cp	#TEXT_ROWS		; and if (cursory >= TEXT_ROWS)
	jr	c, putchar_draw_cursor
	call	_scroll_lcd
	ld	a, #TEXT_ROWS - 1
	ld	(_cursory), a		; cursory = TEXT_ROWS - 1
putchar_draw_cursor:
	ld	a, (_cursory)
	ld	h, a
	ld	a, (_cursorx)
	ld	l, a
	call	screenbuf_offset
	ld	de, #_screenattrs
	add	hl, de			; hl = screenattrs[(cursory * LCD_COLS) + cursorx]
	ld	a, (hl)			; read existing attrs
	set	#ATTR_BIT_CURSOR, a
	ld	(hl), a			; = putchar_sgr | ATTR_CURSOR
	ld	a, (_cursorx)
	ld	l, a
	push	hl
	ld	a, (_cursory)
	ld	l, a
	push	hl
	call	_stamp_char
	pop	hl
	pop	hl
putchar_fastout:
	pop	hl
	pop	de
	ld	sp, ix
	pop	ix
	ret


; void putchar_attr(unsigned char row, unsigned char col, char c, char attr)
; directly manipulates screenbuf/attrs without scrolling or length checks
; row at 4(ix), col at 5(ix), c at 6(ix), attr at 7(ix)
_putchar_attr::
	push	ix
	ld	ix, #0
	add	ix, sp
	push	de
	push	hl
store_char:
	ld	h, 4(ix)
	ld	l, 5(ix)
	call	screenbuf_offset
	push	hl
	ld	de, #_screenbuf
	add	hl, de			; screenbuf[(row * TEXT_COLS) + col]
	ld	a, 6(ix)
	ld	(hl), a
store_attrs:
	pop	hl
	ld	de, #_screenattrs
	add	hl, de			; screenattrs[(row * TEXT_COLS) + col]
	ld	a, 7(ix)
	ld	(hl), a
	ld	l, 5(ix)
	push	hl
	ld	l, 4(ix)
	push	hl
	call	_stamp_char
	pop	hl
	pop	hl
	pop	hl
	pop	de
	ld	sp, ix
	pop	ix
	ret
