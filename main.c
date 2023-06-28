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
unsigned char old_minutes;
unsigned char obuf_sent_pos;

#define MODEM_MSR_DCD	(1 << 7)

int process_keyboard(void);
void process_input(unsigned char b);
void update_clock(void);
void update_f1(void);
void obuf_flush(void);
void wifi_hangup(void);

#define DEBUG

enum {
	SOURCE_MODEM,
	SOURCE_LPT,
	SOURCE_ECHO,
	SOURCE_WIFI,
};
unsigned char source;

enum {
	STATUSBAR_F1,
	STATUSBAR_F2,
	STATUSBAR_F3,
	STATUSBAR_F4,
	STATUSBAR_F5,
	STATUSBAR_INIT,
};

void
obuf_queue(unsigned char *c)
{
	unsigned char x;

	for (x = 0; c[x] != '\0'; x++)
		obuf[obuf_pos++] = c[x];
}

int
main(void)
{
	unsigned char ms[10];
	unsigned char shown_logo;
	int b, j;

	/* ignore first peekkey() if it returns power button */
	lastkey = KEY_POWER;
	esc = 0;
	source = SOURCE_WIFI;
	putchar_sgr = 0;
	in_csi = 0;
	csibuflen = 0;
	obuf_pos = 0;
	obuf_sent_pos = 0;
	debug0 = 0;
	shown_logo = 0;

	patch_isr();

	settings_read();
	clear_screen_bufs();
	clear_screen();
	update_statusbar(STATUSBAR_INIT, NULL);

begin:
	if (source == SOURCE_WIFI)
		/* call this early to sleep while we draw the logo */
		wifi_init();

	if (!shown_logo) {
		/* - 1 to ignore final null byte */
		for (b = 0; b < sizeof(logo) - 1; b++) {
			if (b == 0 || logo[b - 1] == '\n') {
				/* center without wasting space in logo[] */
				for (j = 0; j < 14; j++)
					putchar(' ');
			}

			putchar(logo[b]);
		}
		printf("  v%u\n\n", msTERM_version);
		shown_logo = 1;
	}

	old_minutes = 0xff;
	update_clock();

	update_f1();

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
		obuf_queue("\rAT\r");
		obuf_flush();
		break;
	}

	obuf_flush();

	for (;;) {
		b = process_keyboard();
		if (b == KEY_F4)
			/* we changed sources */
			goto begin;

		switch (source) {
		case SOURCE_MODEM:
			modem_msr();
			if (modem_lsr() & (1 << 0)) {
				process_input(modem_read());
				continue;
			}
			break;
		case SOURCE_LPT:
			b = lptrecv();
			if (b <= 0xff) {
				process_input(b & 0xff);
				continue;
			}
			break;
		case SOURCE_WIFI:
			b = wifi_read();
			if (b != -1) {
				process_input(b & 0xff);
				continue;
			}
			break;
		}

		if (obuf_sent_pos != obuf_pos)
			obuf_flush();

		update_clock();
	}

	return 0;
}

void
update_statusbar(char which, char *status, ...)
{
	va_list args;
	char tstatus[64];
	char *result = NULL;
	unsigned char i, l;

	if (which == STATUSBAR_INIT) {
		for (i = 0; i < LCD_COLS; i++)
			putchar_attr(LCD_ROWS - 1, i,
			    ((i + 1) % 13 == 0 ? '|' : ' '), ATTR_REVERSE);
		return;
	}

	va_start(args, status);
	l = vsprintf(tstatus, status, args);
	va_end(args);

	if (l > sizeof(tstatus)) {
		new_mail(1);
		panic();
	}

	for (i = 0; i < l; i++) {
		putchar_attr(LCD_ROWS - 1, (which * 13) + i, tstatus[i],
		    ATTR_REVERSE);
	}
}

void
update_clock(void)
{
	static const char modem_s[] = "Modem";
	static const char wifi_s[] = "WiFi ";

	if (rtcminutes == old_minutes)
		return;

	update_statusbar(STATUSBAR_F4, "    %s   ",
	    (source == SOURCE_MODEM ? modem_s: wifi_s));
	update_statusbar(STATUSBAR_F5, "   %02d:%02d    ",
	    (rtc10hours * 10) + rtchours,
	    (rtc10minutes * 10) + rtcminutes);

	old_minutes = rtcminutes;
}

void
update_f1(void)
{
	unsigned char s = 0;

	if (source == SOURCE_MODEM) {
		if (modem_curmsr & MODEM_MSR_DCD)
			update_statusbar(STATUSBAR_F1, "   Hangup  ");
		else
			update_statusbar(STATUSBAR_F1, " No Carrier");
	} else if (source == SOURCE_WIFI) {
		update_statusbar(STATUSBAR_F1, "   Hangup  ");
	}
}

int
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
		return 0;

	switch (b) {
	case KEY_POWER:
		powerdown_mode();
		break;
	case KEY_F1:
		if (source == SOURCE_MODEM) {
			if (modem_curmsr & MODEM_MSR_DCD)
				modem_hangup();
		} else if (source == SOURCE_WIFI) {
			wifi_hangup();
		}
		break;
	case KEY_F4:
		if (source == SOURCE_MODEM) {
			printf("\nHanging up modem...\n");
			modem_hangup();
			modem_powerdown();
			printf("\nSwitching to WiFiStation...\n");
			source = SOURCE_WIFI;
		} else if (source == SOURCE_WIFI) {
			printf("\nDisconnecting WiFiStation...\n");
			wifi_hangup();
			printf("\nSwitching to modem...\n");
			source = SOURCE_MODEM;
		}
		break;
	case KEY_MAIN_MENU:
		/* send escape */
		obuf[obuf_pos++] = ESC;
		break;
	case KEY_EMAIL:
		reboot();
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
		update_f1();
		break;
	default:
		if (b >= META_KEY_BEGIN)
			return 0;

		if (b == '\n')
			b = '\r';

		obuf[obuf_pos++] = b;
	}

	return b;
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

void
obuf_flush(void)
{
	int b;

	while (obuf_sent_pos != obuf_pos) {
		switch (source) {
		case SOURCE_MODEM:
			if (modem_lsr() & (1 << 5))
				/* Transmitter Holding Register Empty */
				modem_write(obuf[obuf_sent_pos++]);
			break;
		case SOURCE_LPT:
			lptsend(obuf[obuf_sent_pos++]);
			break;
		case SOURCE_ECHO:
			putchar(obuf[obuf_sent_pos++]);
			break;
		case SOURCE_WIFI:
			if (wifi_write(obuf[obuf_sent_pos]) == -1) {
				if ((b = wifi_read()) != -1)
					process_input(b & 0xff);
			} else
				obuf_sent_pos++;
			break;
		}
	}
}

void
wifi_hangup(void)
{
	obuf[obuf_pos++] = '+';
	obuf[obuf_pos++] = '+';
	obuf[obuf_pos++] = '+';
	obuf_flush();
	delay(800);
	obuf[obuf_pos++] = 'A';
	obuf[obuf_pos++] = 'T';
	obuf[obuf_pos++] = 'H';
	obuf[obuf_pos++] = '\r';
	obuf_flush();
}
