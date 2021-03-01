; vim:syntax=z8a:ts=8:sw=8

	; when running from Loader, we are loaded at 0x8000 and use slot 4
	; for swapping devices
	;
	; CODE_LOC in Makefile should be 0x8100
	.equ	RUN_ADDR,		#0x8000
	.equ	RUN_DEVICE,		#0x8
	.equ	RUN_PAGE,		#0x7
	.equ	SLOT_ADDR,		#0x4000
	.equ	SLOT_DEVICE,		#0x6
	.equ	SLOT_PAGE,		#0x5
