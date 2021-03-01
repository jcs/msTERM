; vim:syntax=z8a:ts=8:sw=8

	; when running from dataflash, we are loaded at 0x4000 and use slot 8
	; for swapping devices
	.equ	RUN_ADDR,		#0x4000
	.equ	RUN_DEVICE,		#0x6
	.equ	RUN_PAGE,		#0x5
	.equ	SLOT_ADDR,		#0x8000
	.equ	SLOT_DEVICE,		#0x8
	.equ	SLOT_PAGE,		#0x7
