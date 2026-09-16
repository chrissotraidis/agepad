# bcdec

Upstream: https://github.com/iOrange/bcdec
Pinned commit: 80859ed3b7afb1c527a2a99d70c61457bea72d0c
File: bcdec.h (local changes described below)
Original pinned SHA-256: 134520764d96f70a27db814173616c89ad85db95fbd3328417c7a8c77e7ca189
License choice: MIT; original copyright and license are included in the header.

Used for the experimental local BC texture fallback. Vendoring this decoder does not establish game integration or GPU format support.

2026-09-10: replaced signed left-shift sign extension with unsigned masking and
bounded subtraction. The all-format CPU decoder test exposed undefined behavior
in BC6H endpoint sign extension under UndefinedBehaviorSanitizer. This preserves
the intended two's-complement result without overflowing a signed shift.
Also made the half-to-float sign-bit shift unsigned; the same sanitizer test
exposed signed overflow when converting negative BC6H values.
Initialized BC7 endpoints before p-bit expansion; alpha-less modes previously
read/shifted uninitialized alpha before replacing it with255.

Current locally patched SHA-256: 622ef8d2e1fad8baf579085f1ff7b0845bdf34143e8d11371530499d1a76152c
