/*
 * msTERM
 *
 * Copyright (c) 2019 joshua stein <jcs@jcs.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef _INCL_MAILSTATION
#define _INCL_MAILSTATION

#include "meta_keys.h"

/* define some ports - see 0x1b2b */
__sfr __at(0x01) portkeyboard;
__sfr __at(0x02) port2;
__sfr __at(0x05) slot4000page;
__sfr __at(0x06) slot4000device;
__sfr __at(0x07) slot8000page;
__sfr __at(0x08) slot8000device;
__sfr __at(0x09) portpowerstatus;
__sfr __at(0x0d) portcpuclockrate;
__sfr __at(0x28) port28;

/* v2.54 firmware */
extern volatile unsigned char __at(0xdba2) p2shadow;
extern volatile unsigned char __at(0xdba3) p3shadow;
extern volatile unsigned char __at(0xdba0) p28shadow;

/* device IDs that can be swapped into page4000 */
#define DEVICE_CODEFLASH	0x00	// 64 pages
#define DEVICE_RAM		0x01	// 08 pages
#define DEVICE_LCD_LEFT		0x02	// 01 pages
#define	DEVICE_DATAFLASH	0x03	// 32 pages
#define DEVICE_LCD_RIGHT	0x04	// 01 pages
#define DEVICE_MODEM		0x05	// 01 pages

/* once DEVICE_LCD_{LEFT,RIGHT} is swapped into page4000, LCD starts here */
#define LCD_START		0x4038

/* LCD parameters (2 screens) */
#define LCD_WIDTH		(160 * 2)			// 320
#define LCD_HEIGHT		128
#define LCD_COL_GROUPS		20
#define LCD_COL_GROUP_WIDTH	8

#define FONT_WIDTH		5
#define FONT_HEIGHT		8

/* columns of characters */
#define LCD_COLS		(LCD_WIDTH / FONT_WIDTH)	// 64
#define LCD_ROWS		(LCD_HEIGHT / FONT_HEIGHT)	// 16
#define TEXT_COLS		LCD_COLS			// 64
#define TEXT_ROWS		(LCD_ROWS - 1)			// 15

#define ATTR_DIRTY		(1 << 0)
#define ATTR_CURSOR		(1 << 1)
#define ATTR_REVERSE		(1 << 2)
#define ATTR_BOLD		(1 << 3)
#define ATTR_UNDERLINE		(1 << 4)

extern char screenbuf[LCD_COLS * LCD_ROWS];
extern char screenattrs[LCD_COLS * LCD_ROWS];

/* for printf */
#define BYTE_TO_BINARY_PATTERN "%c%c%c%c%c%c%c%c"
#define BYTE_TO_BINARY(byte)  \
  (byte & 0x80 ? '1' : '0'), \
  (byte & 0x40 ? '1' : '0'), \
  (byte & 0x20 ? '1' : '0'), \
  (byte & 0x10 ? '1' : '0'), \
  (byte & 0x08 ? '1' : '0'), \
  (byte & 0x04 ? '1' : '0'), \
  (byte & 0x02 ? '1' : '0'), \
  (byte & 0x01 ? '1' : '0')


/* for debugging access from asm */
extern unsigned char debug0;
extern unsigned char debug1;
extern unsigned char debug2;
extern unsigned char debug3;
extern unsigned char debug4;


/* crt0.s */
extern void powerdown_mode(void);
extern void new_mail(unsigned char on);
extern void reboot(void);
extern void delay(unsigned int millis);
extern void lcd_paint(void);


/* mslib.c */
extern void uitoa(unsigned int value, char *string, int radix);
extern void itoa(int value, char *string, int radix);


/* csi.c */
extern void parseCSI(void);
extern unsigned char in_csi;
extern unsigned char csibuf[TEXT_COLS];
extern unsigned int csibuflen;


/* putchar.s */
extern unsigned char cursorx;
extern unsigned char cursory;
extern unsigned char putchar_sgr;
extern unsigned char putchar_quick;
extern unsigned char *font_addr;
extern void lcd_cas(unsigned char col);
extern void lcd_sleep(void);
extern void lcd_wake(void);
extern void uncursor(void);
extern void recursor(void);
extern void clear_screen(void);
extern void dirty_screen(void);
extern void redraw_screen(void);
extern void scroll_lcd_half(void);
extern void clear_lcd_half(void);
extern void stamp_char(unsigned char row, unsigned char col);
extern void putchar_attr(unsigned char row, unsigned char col, unsigned char c,
    unsigned char attr);


/* getchar.s */
extern unsigned char getscancode(unsigned char *charbuffer);
extern char *gets(char *s);
extern int getkey(void);
extern int peekkey(void);
extern int getkeyorlpt(void);


/* lpt.s */
extern unsigned char lptsend(unsigned char b);
extern int lptrecv(void);


/* mailstation.c */
extern unsigned char *firmware_version;
extern void setup(void);
extern void update_statusbar(char *status, ...);


/* modem.s */
extern unsigned char modem_curmsr;
extern int modem_init(void);
extern int modem_ier(void);
extern int modem_iir(void);
extern int modem_lcr(void);
extern int modem_lsr(void);
extern char modem_read(void);
extern void modem_write(char c);


/* msterm.c */
extern unsigned char obuf[TEXT_COLS];
extern unsigned char obuf_pos;

#endif
