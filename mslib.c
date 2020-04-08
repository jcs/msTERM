/*
 * msTERM
 * utility functions
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

/* From Bela Torok, 1999 <bela.torok@kssg.ch> */

#define NUMBER_OF_DIGITS	16

void
uitoa(unsigned int value, char *string, int radix)
{
	unsigned char t[NUMBER_OF_DIGITS + 1];
	unsigned char index, i;

	index = NUMBER_OF_DIGITS;
	i = 0;

	do {
		t[--index] = '0' + (value % radix);
		if (t[index] > '9')
			t[index] += 'A' - ':';
		value /= radix;
	} while (value != 0);

	do {
		string[i++] = t[index++];
	} while (index < NUMBER_OF_DIGITS);

	string[i] = '\0';
}

void
itoa(int value, char *string, int radix)
{
	if (value < 0 && radix == 10) {
		*string++ = '-';
		uitoa(-value, string, radix);
	} else {
		uitoa(value, string, radix);
	}
}
