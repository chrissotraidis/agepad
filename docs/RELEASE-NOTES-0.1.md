# AgePad 0.1.0 (developer preview)

Play your own Steam copy of **Age of Empires II: Definitive Edition** natively on an iPad with 8 GB of memory.

## In this release

- `AgePad-v0.1.0-ios-base.ipa` (about 1 MB): AgePad's own code only. It contains no game or Steam files; `scripts/audit-agepad-base.py` checks this.
- `AgePad-v0.1.0-padmint.json`: the manifest [PadMint](https://github.com/chrissotraidis/padmint) uses to make your personal app.
- `SHA256SUMS` for both.
- Build: game version 488492.107976 (Steam build 25464371), Steam for Mac as of 30 September 2026.

## How to install

1. On a Mac with the game installed through Steam, download the repository and `AgePad-v0.1.0-ios-base.ipa`.
2. Run `scripts/agepad-ipad.sh inject AgePad-v0.1.0-ios-base.ipa`. It adds your own game and Steam files and writes `generated/AgePad-mine.ipa`. Keep that file to yourself. (Or let PadMint do steps 1 and 2.)
3. Install it with Sideloadly, AltStore, or Xcode. A paid Apple Developer account is recommended (full matches); a free Apple ID works for short matches.
4. Copy the `AgeOfEmpires2Data` folder to AgePad with Finder → Files (about 20 GB).
5. Open AgePad, scan the Steam sign-in code with the Steam app on your phone, and play.

## What works

- The real game: menu in about 30 seconds, skirmishes at about 120 fps, save and load.
- Touch, Apple Pencil, mouse, trackpad and keyboard.
  Tap selects, two-finger tap gives orders, two- or three-finger drag moves the map, pinch
  zooms. With the Pencil, tap to select, then each tap gives an order until you hold
  for half a second or double-tap the Pencil. [All controls](https://github.com/chrissotraidis/agepad/blob/main/docs/IPAD-SETUP.md).
- Steam signed in on the iPad itself, online, or offline through Steam's offline mode.

## Known limits

- Tested on one iPad (iPad Pro 12.9-inch, M2, 8 GB).
- Not yet verified: full online matches, sessions over an hour, and a real mouse.
- Without a paid developer account the app gets about 5 GB of memory; a five-player match fits, with little spare, and long matches may be closed by iPadOS.
- If your game or Steam version differs from this release, `inject` stops and says so. Wait for the matching release, or build AgePad yourself ([setup guide](https://github.com/chrissotraidis/agepad/blob/main/docs/IPAD-SETUP.md)).
- Xbox Network sign-in doesn't open yet.

Unofficial fan project, not affiliated with Microsoft, Valve, Feral Interactive or Apple. You need your own copy of the game.
