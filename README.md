## msTERM

A terminal program for the MailStation with the ability to use the internal
modem or parallel port.

msTERM currently targets version 2.54 of the MailStation OS.

![https://i.imgur.com/2l9rXK4.jpg](https://i.imgur.com/2l9rXK4.jpg)

### Features

- Support for controlling the internal modem through typed `AT` comments
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
[SDCC](http://sdcc.sourceforge.net/)
and
[hex2bin](https://sourceforge.net/projects/hex2bin/files/hex2bin/).

Create an `obj` directory with `mkdir obj` and then run `make`.

Then transfer `obj/msterm.bin` to the MailStation with
[Loader](https://github.com/jcs/mailstation-tools)
which will put the application into `0x8000`.

### Flashing to `dataflash`

Edit `Makefile` to change the `--code-loc` argument to `sdcc` to expect to run
from the `0x4000` area, as well as the `.org` line in `crt0.s`.

Load the compiled `obj/msterm.bin` to the `dataflash`... somehow.

### TODO

- Make `putchar` faster (probably just `stamp_char`) because it is currently
  too slow to keep the modem at a high speed without dropping data.

- Add an actual Settings menu to change modem speed through DLAB, speaker
  volume from automated calls, etc.  This will require persisting settings to a
  dataflash page somewhere.

- Add a Call menu to dial saved phone numbers

- Maybe add battery level to status bar

### License

Copyright (c) 2019 [joshua stein](https://jcs.org/)

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
