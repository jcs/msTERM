; vim:syntax=z8a:ts=8:sw=8

	.equ	VERSION,		#0x3

	; these are defined in addrs-*, either of which is linked into the
	; build based on where we're running from
	.globl	RUN_ADDR
	.globl	RUN_DEVICE
	.globl	RUN_PAGE
	.globl	SLOT_ADDR
	.globl	SLOT_DEVICE
	.globl	SLOT_PAGE

	; per-firmware version port shadow variables
	.globl	p2shadow
	.globl	p3shadow
	.globl	p28shadow

	; functions
	.equ	get_keycode_from_buffer,#0x0a9a
	.equ	lcd_buf_to_screen,	#0x2473

	; lcd bit storage buffer, copied with lcd_buf_to_screen
	.equ	lcd_buf,		#0xc010
	.equ	lcd_buf_end,		#lcd_buf + ((LCD_WIDTH * LCD_HEIGHT) / 8) - 1

	; circular char[] buffer offset by *_modem_buf_pos
	.equ	_modem_buf,		#0xf600
	.equ	_modem_buf_pos,		#0xf700
	.equ	_modem_buf_read_pos,	#0xf702

	.equ	_obuf,			#0xf500
	.equ	_obuf_pos,		#0xf704

	; some random dataflash location (0x18000) that looked empty
	.equ	settings_page,		#6
	.equ	settings_sector,	#0		; sectors are 256 bytes

	; some constants from mailstion.h
	.equ	LCD_WIDTH,		#160 * 2		  ; 320
	.equ	LCD_HEIGHT,		#128
	.equ	LCD_COL_GROUPS,		#20
	.equ	LCD_COL_GROUP_WIDTH,	#8
	.equ	FONT_WIDTH,		#5
	.equ	FONT_HEIGHT,		#8
	.equ	LCD_COLS,		#LCD_WIDTH / FONT_WIDTH   ; 64
	.equ	LCD_ROWS,		#LCD_HEIGHT / FONT_HEIGHT ; 16
	.equ	TEXT_ROWS,		#LCD_ROWS - 1		  ; 15

	.equ	DEVICE_RAM,		#0x01
	.equ	DEVICE_LCD_LEFT,	#0x02
	.equ	DEVICE_DATAFLASH,	#0x03
	.equ	DEVICE_LCD_RIGHT,	#0x04
	.equ	DEVICE_MODEM,		#0x05

	; addressing the LCD once it's loaded in SLOT_ADDR
	.equ	LCD_START,		#SLOT_ADDR + 0x0038

	.equ	ATTR_BIT_CURSOR,	#0
	.equ	ATTR_BIT_REVERSE,	#1
	.equ	ATTR_BIT_BOLD,		#2
	.equ	ATTR_BIT_UNDERLINE,	#3

	.equ	ATTR_CURSOR,		#(1 << ATTR_CURSOR)
	.equ	ATTR_REVERSE,		#(1 << ATTR_REVERSE)
	.equ	ATTR_BOLD,		#(1 << ATTR_BOLD)
	.equ	ATTR_UNDERLINE,		#(1 << ATTR_UNDERLINE)

	.equ	MODEM_DEFAULT_SPEED,	#14400
	.equ	ESC,			#0x1b
	.equ	XON,			#0x11
	.equ	XOFF,			#0x13

	.globl	_saved_cursorx
	.globl	_saved_cursory
	.globl	_delay

	; settings
	.globl	_setting_modem_speed
	.globl	_setting_modem_quiet

	.globl	_modem_buf
	.globl	_modem_buf_pos
	.globl	_modem_buf_read_pos
	.globl	_modem_curmsr
	.globl	_modem_flowing

	.globl	_obuf
	.globl	_obuf_pos

	; debug variables
	.globl	_debug0
	.globl	_debug1
