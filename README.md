<p align="center"><img src="docs/images/agepad-icon-256.png" width="128" alt="AgePad icon"></p>

# AgePad

**Your own Steam copy of Age of Empires II: Definitive Edition, running natively on an iPad.** Not a stream, not a remake: the real Mac game, with touch, Apple Pencil, mouse and keyboard controls, and Steam signed in on the iPad itself. Once it's set up, tap the icon and play, with no computer involved, online or offline.

![A skirmish on an iPad Pro](docs/images/ipad-skirmish-20260926.jpg)

> **Status (26 September 2026):** working on an iPad Pro 12.9-inch (M2, 8 GB). Menu in about 30 seconds, skirmishes at about 120 fps, save and resume, offline play through Steam's offline mode. There is no download: you build it on your Mac from your own copy of the game (below). This is an unofficial fan project, not affiliated with Microsoft, Valve, Feral Interactive or Apple.

## What you need

- **The game on Steam:** Age of Empires II: Definitive Edition, installed through Steam on a Mac (the Mac version comes with the Steam purchase).
- **A Mac** (Apple silicon) for the one-time setup.
- **An iPad with 8 GB of memory or more** (for example an iPad Pro with M1/M2/M4, or an iPad Air with M2 or later) and about 25 GB free, plus a USB-C cable.
- **A way to sign apps for your iPad.** Recommended: a paid Apple Developer account (99 USD a year), which gives the app the larger memory limit a full match needs and lasts a year. A free Apple ID (with AltStore or Sideloadly) also works but only for short matches, and needs re-signing every 7 days: see [memory](docs/IPA-ROUTE.md#memory-the-one-real-limit).
- **The Steam app on your phone**, to sign in by scanning a code (or use your Steam password).

## Install

**Option A: from the release (no Xcode).**

1. Download `AgePad-base.ipa` from the [releases](../../releases) and this repository.
2. On your Mac, in this folder: `scripts/agepad-ipad.sh inject `/Downloads/AgePad-base.ipa`. In a few seconds it adds your own game and Steam files and writes `generated/AgePad-mine.ipa`. It's yours only, so don't share it.
3. Install `AgePad-mine.ipa` with your signing tool (Sideloadly, AltStore, or Xcode with a paid account).
4. Connect the iPad, open it in **Finder → Files**, and drag the `AgeOfEmpires2Data` folder (Steam → Age of Empires II: DE → Manage → Browse local files) onto **AgePad**. About 20 GB.
5. Open AgePad and sign in to Steam once by scanning the code with the Steam app on your phone. Then just tap the icon to play.

**Option B: build it yourself (Xcode, paid account).** Prepare signing once (step 1 of the [setup guide](docs/IPAD-SETUP.md)), connect the iPad and run `scripts/agepad-ipad.sh setup`. It checks everything, builds, installs and copies the game files; then sign in on the iPad.

The [setup guide](docs/IPAD-SETUP.md) has the details, full controls and updates; [the IPA route](docs/IPA-ROUTE.md) explains how the release works.

## Playing

- **Touch:** tap to select, two-finger tap to give orders (right click), three-finger drag to move the map, pinch to zoom. Side buttons: R-CLICK, IDLE villager, TOWN center, ZOOM, MENU.
- **Apple Pencil:** tap a unit, then each tap on the map is an order; hold ½ second (or double-tap the Pencil) to stop.
- **Mouse, trackpad and keyboard:** click, right click, drag-select and all the game's hotkeys work as on a computer.
- **Online:** multiplayer and everything else work as usual.
- **Offline (on a flight):** AgePad uses Steam's own offline mode, so single player, skirmishes and campaigns work. Open AgePad once with Internet before you go.
- **HUD size:** starts at 125% on a new install; change it in the game's Options → Interface.
- **Signing out:** iPad Settings → AgePad → *Sign out of Steam*.

## How Steam works here

AgePad runs Valve's own Steam software (taken from your Mac's Steam) inside the app, so the iPad signs in to Steam like any computer. Steam decides whether your account owns the game; AgePad doesn't sell, unlock, share or fake anything, and never sees or stores your password. The iPad appears in your Steam account as "AgePad (iPad)". The Steam app for iPhone/iPad can't run games, and Steam Link needs a computer switched on, so neither replaces this.

## Why the release is only 1 MB

A complete app would contain Microsoft's game program and Valve's Steam software, which aren't ours to distribute, and iPadOS only runs code that is signed into the app itself. So there's no App Store, TestFlight or full IPA. The release holds only AgePad's own code plus a list of which of your files go where (names, hashes and small header changes, no game or Steam content); `inject` assembles your app from your own copy. The release is checked to contain no game or Steam files.

## Keeping it up to date

- **Steam updated on your Mac:** run `scripts/agepad-ipad.sh setup` again with the iPad connected.
- **The game updated:** the iPad tells you. It keeps playing the version it has (single player and offline are fine); online matches need AgePad to support the new version first. Then `setup` copies only the files that changed.

## Known limits

- Needs an iPad with 8 GB of memory; iPhones and smaller iPads are not supported. With a free Apple ID, keep matches short (see memory above).
- Loading a skirmish takes about a minute.
- Xbox Network sign-in (used by some online features) doesn't open yet.
- Tested on one iPad so far. Reports from other iPads are welcome.

---

## For developers

The rest of this file is the engineering history (Simulator runs, repairs and measurements). Current device work is logged in [Steam engine loop](docs/STEAM-ENGINE-LOOP.md) and the [device route log](docs/DEVICE-ROUTE-20260924.md); building from scratch is in [DE-BOOTSTRAP](docs/DE-BOOTSTRAP-20260919.md).

### What works today (Simulator history)

September 19: simulation speed is now 1.62x on Normal (DE's target is 1.7x); the
run-loop pump in our GPU-wait shim was costing the simulation up to 15% of
each second and was cut from 5 ms to 1 ms. Dialog buttons (quit/restart
confirmations, Play Again) no longer miss at low frame rates. Details in
[SPEED-AND-DIALOGS-20260919.md](docs/SPEED-AND-DIALOGS-20260919.md).

September 18 flow pass: a fresh launch now runs end to end — new skirmish on the
first Start Game tap, villager production, house placement and completion,
typed-name save, reload of that save on a new launch, and a background/foreground
cycle with input still accepted afterwards. Two fixes landed: the paste permission
prompt at every launch is gone, and backgrounding no longer crashes the game. The
three compatibility libraries also compile and link for a physical iPad with zero
errors. Xbox Network sign-in and two-finger gestures remain open. Details in
[FLOW-PASS-20260918.md](docs/FLOW-PASS-20260918.md).

September 18: the failed touch movement orders are fixed. The delivery layer
was holding the right button for hundreds of milliseconds while waiting for
slow frames, which the game reads as click-drag scrolling instead of a command.
With the hold capped at 160 ms, 20 consecutive orders were accepted on a fresh
launch without visiting Options, and drag box selection works. Details in
[DE-REPAIR-20260918.md](docs/DE-REPAIR-20260918.md).

September 15 recheck: fresh launch, named-save loading, visible units, selection,
ongoing food gathering and the zoom shortcut passed. Two ground-order attempts
did not move the selected villager. A 30-second observation averaged 9.87
compositions/second with only the designated Simulator booted. Touch movement
and performance are therefore still release blockers, despite earlier successful
runs. No physical-device acceptance is claimed.

The September 14 Simulator repair restores missing villagers and animals by preserving source resource filename casing and resolving case-insensitive reads within the imported game-data tree. The latest candidate has demonstrated selection, a completed house, ground movement, sheep gathering, villager production and a named save/reload. Repeated movement and scout exploration also passed after a fresh launch. A 30-second run averaged 26.3 observed compositions per second, with stalls that still require investigation. Physical iPad gameplay remains unverified.

### Installing (developer summary)

There is no downloadable IPA yet. Today the app is built on a Mac from this repository and your own Steam install, then signed with your Apple developer account and installed over USB. A free Apple account's signature expires after 7 days; a paid developer account lasts a year. The Steam client engine and the game are copied from your Mac, never bundled.

The setup, all described in [the setup guide](docs/IPAD-SETUP.md):

1. On your Mac, install your owned **Mac edition** of AoE II DE through desktop Steam. Windows and Mac executables are not interchangeable.
2. Set up signing once in Xcode (the app needs Apple's larger memory limit).
3. Connect the iPad with a USB-C cable and run `scripts/agepad-ipad.sh setup`. It checks everything, builds and installs AgePad in place, and copies your game files (about 20 GB the first time; later `scripts/agepad-ipad.sh sync` copies only what a game update changed).
4. Open AgePad on the iPad and sign in to Steam once (above). From then on, tap the icon to play, online or offline.

On a new Mac, the first build also needs a one-time build package made from your game with the iPad Simulator (`check` explains; verified from scratch on 26 September, reusing the two Simulator survey results).

Game files, Steam credentials and another person's saves must not be bundled in a public IPA or repository.

### Touch controls (history)

- One-finger tap: select / left click.
- Two-finger tap: order / right click.
- Three-finger drag: move the map (sent as a middle-button drag).
- Pinch: zoom.
- Apple Pencil: tap a unit to select, then each tap on the map is an order until a ½-second hold.
- Side shortcuts: R-click (right-click the next tap), idle villager, town center, zoom and menu.

These are the requested controls, not a claim that all gestures have passed device testing. Current validation details are in [execution status](docs/STATUS.md) and the [reorientation journal](docs/MADEIRA-REORIENTATION.md).

See the [September 14 repair findings](docs/DE-REPAIR-20260914.md) for root causes, tested fixes and remaining acceptance failures.

### Engineering reproduction

### From a clean machine

`python3 scripts/bootstrap-de-simulator.py generated/de-candidate-YYYYMMDD`
rebuilds a Simulator candidate from this repository plus your own Steam install:
it audits the original app, retargets the supplied Metal IR, runs the import
survey, generates the boundary libraries and the measured public constants,
builds the launch-injected libraries and the host relay, installs and records the
package layout. `python3 scripts/prepare-de-game.py` then stages the game data.
[DE-BOOTSTRAP-20260919.md](docs/DE-BOOTSTRAP-20260919.md) lists every stage and
what was verified. On a new machine run `python3 scripts/create-de-simulator.py`
once and export the `AGEPAD_SIMULATOR_UDID` line it prints; the launch-path
scripts read that variable instead of a literal. Runtime packages resolve the same
way: `generated/mac-de-simulator-375` wins if it exists (this Mac), otherwise the
most recently built candidate is used, and `--package` overrides either.

### Test on this MacBook

This workflow runs the iPad build in Xcode Simulator on the Mac, against a
prepared runtime package and your owned Mac game installation. Build the package
with the bootstrap above, or reuse an existing one by passing `--package` and
`--probe` to the session runner.

One-command version (verifies your Steam install, stages the game data, runs the
preflight and launches):

```sh
python3 scripts/prepare-de-game.py --launch my-run-name --seconds 1800
```

Manual steps:

1. Start desktop Steam and keep it running.
2. In Xcode Simulator, boot only **AgePad G5 iPad**. On this Mac its current
   UDID is `3B66F77C-EDAC-419F-9B75-8694A525B19D`; export it as
   `AGEPAD_SIMULATOR_UDID`. Shut down any other booted Simulator first.
3. From the repository, run `python3 scripts/check-de-install.py`.
   Resolve each failed check before launching.
4. Run `python3 scripts/recover-de-session.py my-test-unique-name --seconds 1800`.
   Use a new run name each time. The game closes automatically after 30 minutes;
   save before the deadline. Keep the runner terminal open.
5. Rotate Simulator to landscape if needed, choose Play, skip the cinematic,
   then choose Single Player → Load Game. Use your own save or start a skirmish.
6. Check visible villagers, selection, Order + ground movement, gathering,
   construction, production, zoom, and save/reload. MENU pauses; Cancel resumes.

For structured diagnostics use `python3 scripts/check-de-install.py --json`.
This preflight checks launch prerequisites, not gameplay correctness. Logs and
private runtime files stay under ignored `generated/` paths.

### What a fresh clone cannot supply by itself

The tracked tree holds the compatibility sources (`port/`), the scripts, the
tests and the documentation. The bootstrap rebuilds the runtime and the boundary
libraries from those sources, but three things still come only from you or this
Mac, and a fresh clone's preflight reports the gap:

```
FAIL private_runtime: Missing: game-client-appkit.json, SystemFrameworkCompat.dylib,
SignalTrace.dylib, MainThreadGraphicsWait.dylib, ResourceFileTrace.dylib,
OriginalInputTrace.dylib, AudioOutputCompat.dylib
```

- **A signing identity for a device build.** The Simulator candidate rebuilds
  from source; installing on an iPad still needs your own signing setup.
- **The ~19 GB game-data tree staged next to the installed app.** `simctl
  install` replaces the whole bundle container, so `scripts/prepare-de-game.py`
  has to re-stage it after every install. That is the only step that needs your
  game: everything else is rebuilt from this repository.
- **The designated Simulator.** `AgePad G5 iPad` is a device created locally on
  this Mac (iPad Air 11-inch (M4), iOS 26.5). `simctl create` cannot reproduce a
  chosen UDID, so another machine has to create the device and export
  `AGEPAD_SIMULATOR_UDID`; the launch-path scripts read that variable, and the
  remaining historical references were written for this Mac. The scripts also
  assume an iOS 26.5 runtime and the matching SDK.
- **Your Steam copy of the Mac edition** at exactly the pinned build, with
  desktop Steam running.

Nothing here downloads the game or signs in to Steam: `scripts/prepare-de-game.py`
reads the installation Steam already placed at
`~/Library/Application Support/Steam/steamapps/common/AoE2DE` (or `--source`),
checks version `488492.107976` (Steam's September 24 update), the executable and `libsteam_api` hashes and the
`resources`, `widgetui`, `wwise` and `modes` directories, then stages a copy.
Ownership, sign-in and the download are yours to arrange, and a Steam update
fails the check rather than silently preparing a different build. Launching
additionally needs desktop Steam running, because the Simulator session uses the
host-assisted Steam discovery relay; that dependency is still unresolved for a
self-contained iPad session.

The dated documents in `docs/` cite evidence under `docs/artifacts/`, which is
ignored, so those links do not resolve in a clone either.

### Rebuilding the injected runtime

The six libraries injected into the launch process and the host Steam path relay
are now built from tracked sources in one step:

```sh
python3 scripts/build-de-injected-runtime.py generated/de-injected-runtime-YYYYMMDD
```

Every input is a file in `port/de`; the script writes a manifest with source and
binary identities, checks each library's `LC_BUILD_VERSION` platform against
where it runs (Simulator for the injected libraries, macOS for the relay) and
refuses a non-fresh output directory. It builds only; installing, staging and
launching still follow the steps above. The 2026-09-19 rebuild was compared
against the binaries in use: identical exported and undefined symbol sets apart
from ARC/optimizer codegen differences, and the rebuilt relay binds its socket
and reports `DE_HOST_PATH_RELAY_READY` exactly as the shipped one does.

### Test on a physical iPad

`scripts/agepad-ipad.sh build` builds, signs and installs AgePad in place on a
paired iPad (game files and saves are kept); `scripts/agepad-ipad.sh logs`
fetches the on-device logs. On Chris's iPad the original game reaches its menu
through the in-app Steam engine with no Mac, and has played skirmishes. A
Simulator build cannot be installed on a physical iPad.

Use [DE reproduction notes](docs/DE-REPRODUCE.md), [installation and service requirements](docs/DE-INSTALL-AND-ONLINE-PLAN.md), and [Mac lock diagnosis](docs/MAC-LOCK-DIAGNOSIS.md). Keep only the existing AgePad G5 iPad Simulator booted. Generated packages, logs and game data are private development artifacts.

The [September 24 first-run audit](docs/UX-FIRST-RUN-20260924.md) records the actual setup, screens, playable Simulator slice, remaining UX work and physical-device gate.
