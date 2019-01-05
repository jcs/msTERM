/*
 * mailstation utility functions
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

#include "mailstation.h"

volatile unsigned char __at(0x0) mem0;
volatile unsigned char __at(0xdba2) p2shadow;
volatile unsigned char __at(0xdba3) p3shadow;
volatile unsigned char __at(0xdba0) p28shadow;

volatile unsigned char *memp = &mem0;

char *
gets(char *s)
{
	char c;
	unsigned int count = 0;

	for (;;) {
		c = getchar();
		switch(c) {
		case '\b': // backspace
			if (count) {
				putchar ('\b');
				putchar (' ');
				putchar ('\b');
				s--;
				count--;
			}
			break;
		case '\n':
		case '\r': // CR or LF
			putchar('\r');
			putchar('\n');
			*s=0;
			return s;
		default:
			*s++=c;
			count++;
			putchar(c);
			break;
		}
	}
}

void
update_statusbar(char *status, ...)
{
	va_list args;
	char tstatus[255], c;
	char *result = NULL;
	unsigned char x, l;

	va_start(args, status);
	vsprintf(tstatus, status, args);
	va_end(args);

	l = strlen(tstatus);

	for (x = 0; x < TEXT_COLS; x++) {
		if (x >= l)
			c = ' ';
		else
			c = tstatus[x];

		putchar_attr(LCD_ROWS - 1, x, c, ATTR_REVERSE);
	}

	redraw_screen();
}
