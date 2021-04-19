## msTERM

A terminal program for the MailStation with the ability to use the internal
modem or parallel port.

msTERM currently targets version 2.54 of the MailStation OS.

![https://i.imgur.com/2l9rXK4.jpg](https://i.imgur.com/2l9rXK4.jpg)

### Features

- Support for [WiFiStation](https://jcs.org/wifistation) (`SOURCE_WIFI`)
- Support for controlling the internal modem through `AT` comments
  (`SOURCE_MODEM`)
- Support for interfacing with the parallel port like a serial port with
[`tribble_getty`](https://github.com/jcs/mailstation-tools/blob/master/util/tribble_getty.c)
on the host side
- Custom version of
[Spleen 5x8](https://github.com/fcambus/spleen)
with DOS 437 codepage characters giving a 64x14 terminal window with a
status bar
- Blinking the "New Mail" LED when modem data transfers
- Caps Lock key can be used as a Control key and Main Menu as Escape

### Compiling

Install
[SDCC](http://sdcc.sourceforge.net/).

Create an `obj` directory with `mkdir obj` and then run `make LOC=ram` to
compile to run out of RAM (from Loader).

Then transfer `obj/msterm.bin` to the MailStation with
[Loader](https://github.com/jcs/mailstation-tools)
which will put the application into `0x8000`.

### License

Copyright (c) 2019-2021 [joshua stein](https://jcs.org/)

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
