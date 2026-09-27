# Third-party notices

## What the iPad app contains

`AgePad-base.ipa` holds only AgePad's own code (the iPad compatibility libraries,
launcher, settings and icons) and a list of which of your files go where. It
contains no game or Steam files; `scripts/audit-agepad-base.py` checks every file
against your local game and Steam installs.

One piece of third-party code is compiled into it:

| Component | Where | License |
|---|---|---|
| [bcdec](https://github.com/iOrange/bcdec) by Sergii Kudlai | `port/de/BC6Kernel.*`, `port/de/BC7Kernel.*`, `port/de/BCBasicKernel.inc` (texture decoding on the GPU) | MIT; the notice is kept in each file |

## What you add yourself

`scripts/agepad-ipad.sh inject` and `build` add, from your own Mac:

- Age of Empires II: Definitive Edition for Mac (Forgotten Empires, World's Edge,
  Xbox Game Studios; Mac version by Feral Interactive), under your game licence.
- Steam for Mac's client libraries (Valve), under the Steam Subscriber Agreement.

AgePad does not distribute either, and no AgePad licence covers them. The
`AgePad-mine.ipa` that `inject` writes contains them, so keep it to yourself.

## Earlier routes kept in the repository

These files come from routes AgePad tried before the Mac game ran on the iPad.
None of them is built into the iPad app. Each is a modification of another
project and stays under that project's licence:

| Files | Project | License |
|---|---|---|
| `port/patches/freeaoe-macos-build.patch` | [freeaoe](https://github.com/sandsmark/freeaoe) (pinned in `dependencies.lock.json`) | GPL-3.0-or-later |
| `port/windows/patches/wine.patch` | [Wine](https://www.winehq.org) | LGPL-2.1-or-later |
| `port/windows/patches/fex.patch` | [FEX-Emu](https://github.com/FEX-Emu/FEX) | MIT |
| `port/windows/patches/madeira.patch` | [Madeira](https://github.com/willfaust/Madeira) | GPL-3.0 |
| `port/metal/*.patch`, `port/metal/ANGLE-LICENSE` | [ANGLE](https://chromium.googlesource.com/angle/angle) and [SFML](https://www.sfml-dev.org) | BSD-3-Clause (ANGLE, licence kept in `port/metal/ANGLE-LICENSE`); zlib (SFML) |

Pinned revisions for these are in `dependencies.lock.json` and
`port/metal/dependencies.lock.json`.
