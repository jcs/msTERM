/*
 * msTERM
 * ANSI CSI parser
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

unsigned char csibuf[TEXT_COLS];
unsigned int csibuflen;

unsigned char in_csi;

void
parseCSI(void)
{
	int x, y, serviced;
	int param1 = -1, param2 = -1;
	char c = csibuf[csibuflen - 1];
	char parambuf[4];
	int parambuflen, off;
#ifdef DEBUG
	char sb[TEXT_COLS];
#endif

	if (c < 'A' || (c > 'Z' && c < 'a') || c > 'z')
		return;

	switch (c) {
	case 'A':
	case 'B':
	case 'C':
	case 'D':
	case 'E':
	case 'F':
	case 'G':
	case 'J':
	case 'K':
	case 'S':
	case 'T':
	case 'd':
	case 'g':
		/* optional multiplier */
		if (c == 'J' || c == 'K')
			param1 = 0;
		else
			param1 = 1;

		if (csibuflen > 1) {
			for (x = 0; x < csibuflen - 1, x < 4; x++) {
				parambuf[x] = csibuf[x];
				parambuf[x + 1] = '\0';
			}
			param1 = atoi(parambuf);
		}
		break;
	case 'H':
	case 'f':
		/* two optional parameters separated by ; each defaulting to 1 */
		param1 = 1;
		param2 = 1;

		y = -1;
		for (x = 0; x < csibuflen; x++) {
			if (csibuf[x] == ';') {
				y = x;
				break;
			}
		}
		if (y == -1)
			/* CSI 17H -> CSI 17; */
			y = csibuflen - 1;

		if (y > 0) {
			for (x = 0; x < y && x < 4; x++) {
				parambuf[x] = csibuf[x];
				parambuf[x + 1] = '\0';
			}
			param1 = atoi(parambuf);

			if (y < csibuflen - 2) {
				parambuf[0] = '\0';
				for (x = 0; x < (csibuflen - 1 - y) && x < 4; x++) {
					parambuf[x] = csibuf[y + 1 + x];
					parambuf[x + 1] = '\0';
				}
				param2 = atoi(parambuf);
			}
		}
		break;
	}

	serviced = 1;

	uncursor();

	switch (c) {
	case 'A': /* CUU - cursor up */
		for (x = 0; x < param1; x++)
			if (cursory > 0)
				cursory--;
		break;
	case 'B': /* CUD - cursor down */
		for (x = 0; x < param1; x++)
			if (cursory < TEXT_ROWS - 1)
				cursory++;
		break;
	case 'C': /* CUF - cursor forward */
		for (x = 0; x < param1; x++)
			if (cursorx < TEXT_COLS)
				cursorx++;
		break;
	case 'D': /* CUB - cursor back */
		for (x = 0; x < param1; x++)
			if (cursorx > 0)
				cursorx--;
		break;
	case 'E': /* CNL - cursor next line */
		cursorx = 0;
		for (x = 0; x < param1; x++)
			if (cursory < TEXT_ROWS - 1)
				cursory++;
		break;
	case 'F': /* CPL - cursor previous line */
		cursorx = 0;
		for (x = 0; x < param1; x++)
			if (cursory > 0)
				cursory--;
		break;
	case 'G': /* CHA - cursor horizontal absolute */
		if (param1 > TEXT_COLS)
			param1 = TEXT_COLS;
		cursorx = param1;
		break;
	case 'H': /* CUP - cursor absolute position */
	case 'f': /* HVP - horizontal vertical position */
		if (param1 - 1 < 0)
			cursory = 0;
		else if (param1 > TEXT_ROWS)
			cursory = TEXT_ROWS - 1;
		else
			cursory = param1 - 1;

		if (param2 - 1 < 0)
			cursorx = 0;
		else if (param2 > TEXT_COLS)
			cursorx = TEXT_COLS - 1;
		else
			cursorx = param2 - 1;

		break;
	case 'J': /* ED - erase in display */
		if (param1 == 0) {
			/* clear from cursor to end of screen */
			for (y = cursory; y < TEXT_ROWS; y++) {
				for (x = 0; x < TEXT_COLS; x++) {
					if (y == cursory && x < cursorx)
						continue;

					putchar_attr(x, y, ' ', 0);
				}
			}
		} else if (param1 == 1) {
			/* clear from cursor to beginning of the screen */
			for (y = cursory; y >= 0; y--) {
				for (x = TEXT_COLS; x >= 0; x--) {
					if (y == cursory && x > cursorx)
						continue;

					putchar_attr(x, y, ' ', 0);
				}
			}
		} else if (param1 == 2) {
			/* clear entire screen */
			for (y = 0; y < TEXT_ROWS; y++) {
				for (x = 0; x < TEXT_COLS; x++)
					putchar_attr(x, y, ' ', 0);
			}
		}

		break;
	case 'K': /* EL - erase in line */
		if (param1 == 0) {
			/* clear from cursor to end of line */
			for (x = cursorx; x < TEXT_COLS; x++)
				putchar_attr(x, cursory, ' ', 0);
		} else if (param1 == 1) {
			/* clear from cursor to beginning of line */
			for (x = cursorx; x >= 0; x--)
				putchar_attr(x, cursory, ' ', 0);
		} else if (param1 == 2) {
			/* clear entire line */
			for (x = 0; x < TEXT_COLS - 1; x++)
				putchar_attr(x, cursory, ' ', 0);
		}
		break;
	case 'S': /* SU - scroll up */
		/* TODO */
		break;
	case 'T': /* SD - scroll down */
		/* TODO */
		break;
	case 'd': /* absolute line number */
		if (param1 < 1)
			cursory = 0;
		else if (param1 > TEXT_ROWS)
			cursory = TEXT_ROWS;
		else
			cursory = param1 - 1;
		break;
	case 'g': /* clear tabs, ignore */
		break;
	case 'h': /* reset, ignore */
		break;
	case 'm': /* graphic changes */
		parambuf[0] = '\0';
		parambuflen = 0;

		off = (cursory * LCD_COLS) + cursorx;
		param2 = screenattrs[off];

		for (x = 0; x < csibuflen; x++) {
			/* all the way to csibuflen to catch 'm' */
			if (csibuf[x] == ';' || csibuf[x] == 'm') {
				param1 = atoi(parambuf);

				switch (param1) {
				case 0: /* reset */
				case 22: /* normal color */
					param2 = 0;
					break;
				case 1: /* bold */
					param2 |= ATTR_BOLD;
					break;
				case 4: /* underline */
					param2 |= ATTR_UNDERLINE;
					break;
				case 7: /* reverse */
					param2 |= ATTR_REVERSE;
					break;
				case 21: /* bold off */
					param2 &= ~(ATTR_BOLD);
					break;
				case 24: /* underline off */
					param2 &= ~(ATTR_UNDERLINE);
					break;
				case 27: /* inverse off */
					param2 &= ~(ATTR_REVERSE);
					break;
				}

				parambuf[0] = '\0';
				parambuflen = 0;
			} else if (parambuflen < 4) {
				parambuf[parambuflen] = csibuf[x];
				parambuflen++;
				parambuf[parambuflen] = '\0';
			}
		}

		putchar_sgr = param2;
		putchar_attr(cursorx, cursory, screenbuf[off], param2);

		break;
	case 'n': /* DSR - device status report */
		if (param1 == 5) {
			/* ok */
			obuf[obuf_pos++] = 27;
			obuf[obuf_pos++] = '[';
			obuf[obuf_pos++] = '0';
			obuf[obuf_pos++] = 'n';
		} else if (param1 == 6) {
			/* CPR - report cursor position */
			obuf[obuf_pos++] = 27;
			obuf[obuf_pos++] = '[';

			itoa(cursory + 1, parambuf, 10);
			for (x = 0; x < sizeof(parambuf); x++) {
				if (parambuf[x] == '\0')
					break;
				obuf[obuf_pos++] = parambuf[x];
			}
			obuf[obuf_pos++] = ';';

			itoa(cursorx + 1, parambuf, 10);
			for (x = 0; x < sizeof(parambuf); x++) {
				if (parambuf[x] == '\0')
					break;
				obuf[obuf_pos++] = parambuf[x];
			}

			obuf[obuf_pos++] = 'R';
		}
		break;
	default:
		/*
		 * if the last character is a letter and we haven't serviced
		 * it, assume it's a sequence we don't support and should just
		 * suppress
		 */
		if (c < 65 || (c > 90 && c < 97) || c > 122)
			serviced = 0;
	}

	if (serviced) {
		recursor();
#ifdef DEBUG
		sprintf(sb, "CSI (%d,%d): ", param1, param2);
		for (x = 0; x < csibuflen; x++)
			sprintf(sb, "%s%c", sb, csibuf[x]);
		update_statusbar(sb);
#endif
		csibuflen = 0;
		csibuf[0] = '\0';
		in_csi = 0;
	}
}
