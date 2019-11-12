; vim:syntax=z8a:ts=8:sw=8

;	; when running from Loader, we are loaded at 0x8000 and use slot 4
;	; for swapping devices
;	;
;	; the --code-loc parameter in Makefile should be 0x8100
;	.equ	RUN_ADDR,		#0x8000
;	.equ	RUN_DEVICE,		#0x8
;	.equ	RUN_PAGE,		#0x7
;	.equ	SLOT_ADDR,		#0x4000
;	.equ	SLOT_DEVICE,		#0x6
;	.equ	SLOT_PAGE,		#0x5

	; when running from dataflash, we are loaded at 0x4000 and use slot 8
	; for swapping devices
	;
	; the --code-loc parameter in Makefile should be 0x4100
	.equ	RUN_ADDR,		#0x4000
	.equ	RUN_DEVICE,		#0x6
	.equ	RUN_PAGE,		#0x5
	.equ	SLOT_ADDR,		#0x8000
	.equ	SLOT_DEVICE,		#0x8
	.equ	SLOT_PAGE,		#0x7


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

	.equ	MODEM_DEFAULT_SPEED,	#300

	.equ	_mem0,			#0
	.globl	_mem0

	.globl	_saved_cursorx
	.globl	_saved_cursory

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

	; some commonly used functions
	.globl	_delay
	.globl	_lptsend
	.globl	_lptsend16
	.globl	_lptrecv
	.globl	div16
	.globl	mult8
	.globl	mult16
