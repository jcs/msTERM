; vim:syntax=z8a:ts=8:sw=8

	; for firmware v2.54
	; variables
	.equ	p2shadow,		#0xdba2
	.equ	p3shadow,		#0xdba3
	.equ	p28shadow,		#0xdba0

	; functions
	.equ	get_keycode_from_buffer,#0x0a9a
	.equ	lcd_buf_to_screen,	#0x2473

	; buffers
	.equ	lcd_buf,		#0xc010
	.equ	lcd_buf_end,		#0xc010 + ((LCD_WIDTH * LCD_HEIGHT) / 8) - 1

	; circular char[] buffer offset by *modem_buf_pos
	.equ	modem_buf,		#0xf600
	.equ	modem_buf_pos,		#0xf700
	.equ	modem_buf_read_pos,	#0xf702

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

	.equ	DEVICE_LCD_LEFT,	#0x02
	.equ	DEVICE_DATAFLASH,	#0x03
	.equ	DEVICE_LCD_RIGHT,	#0x04

	; addressing the LCD once it's in slot4000_device
	.equ	LCD_START,		#0x4038

	.equ	ATTR_BIT_CURSOR,	#0
	.equ	ATTR_BIT_REVERSE,	#1
	.equ	ATTR_BIT_BOLD,		#2
	.equ	ATTR_BIT_UNDERLINE,	#3

	.equ	ATTR_CURSOR,		#(1 << ATTR_CURSOR)
	.equ	ATTR_REVERSE,		#(1 << ATTR_REVERSE)
	.equ	ATTR_BOLD,		#(1 << ATTR_BOLD)
	.equ	ATTR_UNDERLINE,		#(1 << ATTR_UNDERLINE)

	.equ	MODEM_DEFAULT_SPEED,	#300

	.globl	_saved_cursorx
	.globl	_saved_cursory

	; settings
	.globl	_setting_modem_speed
	.globl	_setting_modem_quiet

	; debug variables
	.globl	_debug0
	.globl	_debug1

	; some commonly used functions
	.globl	_delay
	.globl	_lptsend
	.globl	_lptsend16
	.globl	div16
	.globl	mult8
	.globl	mult16
