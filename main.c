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
#include "logo.h"

unsigned char lastkey;
unsigned char esc;
unsigned char old_modem_msr;
unsigned char old_minutes;
unsigned char old_statusbar_left_len;
unsigned char old_statusbar_right_len;

#define MODEM_MSR_DCD	(1 << 7)

void process_keyboard(void);
void process_input(unsigned char b);
void maybe_update_statusbar(unsigned char force);

#define DEBUG

enum {
	SOURCE_MODEM,
	SOURCE_LPT,
	SOURCE_ECHO,
	SOURCE_WIFI,
};
unsigned char source;

#define STATUSBAR_CALL		"     Call    "
#define STATUSBAR_HANGUP	"    Hangup   "
#define STATUSBAR_BLANK		"             "
#define STATUSBAR_SETTINGS	"  Settings   "
#define STATUSBAR_PAUSE		"    Pause    "
#define STATUSBAR_CONTINUE	"  Continue   "
unsigned char statusbar_state;
unsigned char statusbar_time[16];

void
obuf_queue(unsigned char *c)
{
	unsigned char x;

	for (x = 0; c[x] != '\0'; x++)
		obuf[obuf_pos++] = c[x];
}

int main(void)
{
	unsigned char old_obuf_pos;
	unsigned char ms[10];
	unsigned int b, j;

restart:
	/* ignore first peekkey() if it returns power button */
	lastkey = KEY_POWER;
	esc = 0;
	source = SOURCE_WIFI;
	putchar_sgr = 0;
	in_csi = 0;
	csibuflen = 0;
	obuf_pos = 0;
	old_obuf_pos = 0;
	old_modem_msr = 0;
	old_minutes = 0;
	old_statusbar_left_len = 0;
	old_statusbar_right_len = 0;
	debug0 = 0;

	settings_read();
	clear_screen_bufs();
	clear_screen();
	update_statusbar(STATUSBAR_INIT, NULL);

	/* - 1 to ignore final null byte */
	for (b = 0; b < sizeof(logo) - 1; b++) {
		if (b == 0 || logo[b - 1] == '\n') {
			/* center logo without wasting space in logo[] */
			for (j = 0; j < 14; j++)
				putchar(' ');
		}

		putchar(logo[b]);
	}
	printf("  v%u\n\n", msTERM_version);

	switch (source) {
	case SOURCE_MODEM:
		modem_init();

		/* Restore factory configuration 0 */
		obuf_queue("AT&F0");
		/* Select modulation - V.34, automode, min_rate */
		obuf_queue("+MS=11,1,300,");
		/* max_rate */
		itoa(setting_modem_speed, ms, 10);
		obuf_queue(ms);
		/* Turn speaker off */
		obuf_queue("M0");
		/* Allow result codes to DTE */
		obuf_queue("Q0");
		/* Set low speaker volume */
		obuf_queue("L0");
		/* Enable transparent XON/XOFF flow control */
		obuf_queue("&K5\r");
		break;
	case SOURCE_WIFI:
		wifi_init();
		obuf_queue("\rAT\r");
		break;
	}

	maybe_update_statusbar(1);

	for (;;) {
		process_keyboard();

		switch (source) {
		case SOURCE_MODEM:
			modem_msr();
			if (modem_lsr() & (1 << 0))
				process_input(modem_read());
			break;
		case SOURCE_LPT:
			b = lptrecv();
			if (b <= 0xff)
				process_input(b & 0xff);
			break;
		case SOURCE_WIFI:
			b = wifi_read();
			if (b != -1)
				process_input(b & 0xff);
			break;
		}

		if (old_obuf_pos != obuf_pos) {
			switch (source) {
			case SOURCE_MODEM:
				if (modem_lsr() & (1 << 5))
					/* Transmitter Holding Register Empty */
					modem_write(obuf[old_obuf_pos++]);
				break;
			case SOURCE_LPT:
				lptsend(obuf[old_obuf_pos++]);
				break;
			case SOURCE_ECHO:
				putchar(obuf[old_obuf_pos++]);
				break;
			case SOURCE_WIFI:
				if (wifi_write(obuf[old_obuf_pos]) != -1)
					old_obuf_pos++;
				break;
			}
		}

		maybe_update_statusbar(0);
	}

	return 0;
}

void
update_statusbar(short which, char *status, ...)
{
	va_list args;
	char tstatus[64], c;
	char *result = NULL;
	unsigned char i, x, l, mx;

	if (which == STATUSBAR_INIT) {
		for (i = 0; i < LCD_COLS; i++)
			putchar_attr(LCD_ROWS - 1, i, ' ', ATTR_REVERSE);
		return;
	}

	va_start(args, status);
	l = vsprintf(tstatus, status, args);
	va_end(args);

	if (which == STATUSBAR_LEFT)
		mx = (l > old_statusbar_left_len ? l : old_statusbar_left_len);
	else
		mx = (l > old_statusbar_right_len ? l : old_statusbar_right_len);

	if (mx > LCD_COLS)
		mx = LCD_COLS;

	for (i = 0; i < mx; i++) {
		if (which == STATUSBAR_LEFT) {
			if (i >= l)
				c = ' ';
			else
				c = tstatus[i];
			x = i;
		} else {
			if (i >= l)
				c = ' ';
			else
				c = tstatus[l - 1 - i];
			x = LCD_COLS - 1 - i;
		}

		putchar_attr(LCD_ROWS - 1, x, c, ATTR_REVERSE);
	}

	if (which == STATUSBAR_LEFT)
		old_statusbar_left_len = l;
	else if (which == STATUSBAR_RIGHT)
		old_statusbar_right_len = l;
}

void
maybe_update_statusbar(unsigned char force)
{
	unsigned char s = 0;
	unsigned char update = 0;

	if (source == SOURCE_MODEM) {
		if (modem_curmsr & MODEM_MSR_DCD)
			s |= (1 << 0); /* DCD set, call in progress */
	}

	if (force || s != statusbar_state) {
		update_statusbar(STATUSBAR_LEFT, "%s%s",
		    statusbar_state & (1 << 0) ? STATUSBAR_HANGUP : STATUSBAR_CALL,
		    STATUSBAR_SETTINGS);

		statusbar_state = s;
	}

	if (force || (rtcminutes != old_minutes)) {
		old_minutes = rtcminutes;
		if (source == SOURCE_MODEM)
			update_statusbar(STATUSBAR_RIGHT, "%5u | %02d:%02d ",
			    setting_modem_speed,
			    (rtc10hours * 10) + rtchours,
			    (rtc10minutes * 10) + rtcminutes);
		else
			update_statusbar(STATUSBAR_RIGHT, "%02d:%02d    ",
			    (rtc10hours * 10) + rtchours,
			    (rtc10minutes * 10) + rtcminutes);
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
#if 0
		/* XXX: this triggers erroneously */
		powerdown_mode();
#endif
		break;
	case KEY_F1:
		if (modem_curmsr & MODEM_MSR_DCD)
			modem_hangup();
		break;
	case KEY_MAIN_MENU:
		/* send escape */
		obuf[obuf_pos++] = ESC;
		break;
	case KEY_PAGE_UP:
		obuf[obuf_pos++] = ESC;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = '5';
		obuf[obuf_pos++] = '~';
		break;
	case KEY_PAGE_DOWN:
		obuf[obuf_pos++] = ESC;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = '6';
		obuf[obuf_pos++] = '~';
		break;
	case KEY_UP:
		obuf[obuf_pos++] = ESC;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'A';
		break;
	case KEY_DOWN:
		obuf[obuf_pos++] = ESC;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'B';
		break;
	case KEY_LEFT:
		obuf[obuf_pos++] = ESC;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'D';
		break;
	case KEY_RIGHT:
		obuf[obuf_pos++] = ESC;
		obuf[obuf_pos++] = '[';
		obuf[obuf_pos++] = 'C';
		break;
	case KEY_SIZE:
		redraw_screen();
		maybe_update_statusbar(1);
		break;
	default:
		if (b >= META_KEY_BEGIN)
			return;

		if (b == '\n')
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

		if (b == ESC) {
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
	case 26: /* ^Z end of ansi */
		break;
	case ESC: /* esc */
		if (esc)
			/* our previous esc is literal */
			putchar(b);
		esc = 1;
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
