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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "mailstation.h"

/* circular buffer */
unsigned char obuf[TEXT_COLS];
unsigned char obuf_pos;

extern volatile unsigned char mem0;

unsigned char lastkey;
unsigned char esc;
unsigned char old_modem_msr;

#define MODEM_BUF	0xf600
#define MODEM_BUF_POS	0xf700
volatile unsigned char __at(MODEM_BUF) _modem_buf;
volatile unsigned char __at(MODEM_BUF_POS) modem_buf_pos;

#define MODEM_MSR_DCD	(1 << 7)

void process_keyboard(void);
void process_input(unsigned char b);
void maybe_update_statusbar(unsigned char force);

#define DEBUG

enum {
	SOURCE_MODEM,
	SOURCE_LPT,
};
unsigned char source;

#define STATUSBAR_CALL		"     Call    "
#define STATUSBAR_HANGUP	"    Hangup   "
#define STATUSBAR_BLANK		"             "
#define STATUSBAR_SETTINGS	"  Settings  "
unsigned char statusbar_state;

int main(void)
{
	unsigned char *memp = &mem0;
	unsigned char *modem_buf = &_modem_buf;
	unsigned char old_obuf_pos;
	unsigned int b;
	unsigned char old_modem_buf_pos;

restart:
	lastkey = 0;
	esc = 0;
	source = SOURCE_MODEM; //LPT;
	putchar_sgr = 0;
	putchar_quick = 0;
	in_csi = 0;
	csibuflen = 0;
	obuf_pos = 0;
	old_obuf_pos = 0;
	old_modem_msr = 0;
	debug0 = 0;

	clear_screen();
	maybe_update_statusbar(1);

	if (source == SOURCE_MODEM) {
		printf("powering up modem...");
		modem_init();
		printf("\n");
		obuf[obuf_pos++] = 'A';
		obuf[obuf_pos++] = 'T';
		obuf[obuf_pos++] = '\r';

		old_modem_buf_pos = modem_buf_pos;
	}

	for (;;) {
		process_keyboard();

		if (source == SOURCE_MODEM) {
			while (old_modem_buf_pos != modem_buf_pos) {
				if (!putchar_quick)
					putchar_quick = 1;

				//lptsend(modem_buf[old_modem_buf_pos]);
				process_input(modem_buf[old_modem_buf_pos]);
				old_modem_buf_pos++;
			}

			if (putchar_quick) {
				putchar_quick = 0;
				redraw_screen();
			}
		} else if (source = SOURCE_LPT) {
			b = lptrecv();
			if (b <= 0xff)
				process_input(b & 0xff);
		}

		while (old_obuf_pos != obuf_pos) {

			if (source == SOURCE_MODEM) {
#if 0
				lsr = modem_lsr();
				if (lsr & (1 << 5))
#endif
					/* Transmitter Holding Register Empty (THRE) */
					modem_write(obuf[old_obuf_pos]);
			} else if (source == SOURCE_LPT) {
				lptsend(obuf[old_obuf_pos]);
			} else {
				putchar(obuf[old_obuf_pos]);
			}

			old_obuf_pos++;
		}

		maybe_update_statusbar(0);
	}

	return 0;
}

void
maybe_update_statusbar(unsigned char force)
{
	unsigned char s;
	unsigned char old_state = statusbar_state;

	if (modem_curmsr & MODEM_MSR_DCD)
		s = 1; /* DCD, change to 'hangup' */
	else
		s = 0;

	if (s != (statusbar_state & (1 << 0)))
		statusbar_state ^= (1 << 0);

	if ((statusbar_state != old_state) || force) {
		update_statusbar("%s%s%s%s%s",
		    statusbar_state & (1 << 0) ? STATUSBAR_HANGUP : STATUSBAR_CALL,
		    STATUSBAR_BLANK,
		    STATUSBAR_BLANK,
		    STATUSBAR_BLANK,
		    STATUSBAR_SETTINGS);
	}
}

void
process_keyboard(void)
{
	unsigned char b;

	b = peekkey();

	/* this breaks key-repeat, but it's needed to debounce */
	if (b == 0)
		lastkey = 0;
	else if (b == lastkey)
		b = 0;
	else
		lastkey = b;

	if (b == 0)
		return;

	switch (b) {
	case KEY_POWER:
		__asm
			jp 0x0000
		__endasm;
		break;
	case KEY_F1:
		if (modem_curmsr & MODEM_MSR_DCD) {
		}

		break;
	case KEY_BACK:
		/* send escape */
		obuf[obuf_pos++] = 27;
		break;
	case KEY_PAGE_UP:
		obuf[obuf_pos++] = 27;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = '5';
		obuf[obuf_pos++] = '~';
		break;
	case KEY_PAGE_DOWN:
		obuf[obuf_pos++] = 27;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = '6';
		obuf[obuf_pos++] = '~';
		break;
	case KEY_UP:
		obuf[obuf_pos++] = 27;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'A';
		break;
	case KEY_DOWN:
		obuf[obuf_pos++] = 27;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'B';
		break;
	case KEY_LEFT:
		obuf[obuf_pos++] = 27;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'D';
		break;
	case KEY_RIGHT:
		obuf[obuf_pos++] = 27;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'C';
		break;
	case KEY_SIZE:
		//clear_screen();
		redraw_screen();
		break;
	default:
		if (b >= META_KEY_BEGIN)
			return;

		if (source == SOURCE_MODEM && b == '\n')
			b = '\r';

		obuf[obuf_pos++] = b;
	}
}

void
process_input(unsigned char b)
{
	if (in_csi) {
		if (csibuflen >= sizeof(csibuf) - 1) {
			/* going to overflow, dump */
			parseCSI();
			in_csi = 0;
			esc = 0;
			csibuf[0] = '\0';
			csibuflen = 0;
		}

		if (b == 27) {
			/* esc, maybe new csi, dump previous */
			parseCSI();
			in_csi = 0;
			esc = 1;
			csibuf[0] = '\0';
			csibuflen = 0;
		} else {
			csibuf[csibuflen] = b;
			csibuflen++;
			parseCSI();
		}

		return;
	}

	switch (b) {
	case 7: /* visual bell, ping 'new mail' light */
		new_mail(1);
		delay(500);
		new_mail(0);
		break;
	case 9: /* tab */
		while ((cursorx + 1) % 8 != 0)
			putchar(' ');
		break;
	case 27: /* esc */
		if (esc)
			/* our previous esc is literal */
			putchar(b);
		esc = 1;
		break;
	case 26: /* ^Z end of ansi */
		break;
	case 91: /* [ */
		if (esc) {
			esc = 0;
			in_csi = 1;
			break;
		}
		/* fall through */
	default:
		putchar(b);
	}
}
