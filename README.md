# AgePad

Age of Empires II: Definitive Edition on iPad, using your own Steam copy of the original ARM64 Mac game and an iPad compatibility layer. This is a development project, not yet a downloadable IPA.

**Start here: [Playing AgePad on your iPad](docs/IPAD-SETUP.md)** — what you need, how Steam is used, setup steps and controls. On the Mac, `scripts/agepad-ipad.sh check` tells you what is ready and what is missing.

**26 September 2026, physical iPad Pro 12.9-inch (M2, 8 GB):** the game now runs with no Mac at play time. AgePad carries Valve's own Steam client engine and signs in to Steam on the iPad itself. Tapping the icon reaches the main menu in about 30–60 seconds. With Internet blocked, Steam's offline mode starts the game to the menu. Earlier (25 September) the game played a skirmish with touch and Apple Pencil, with audio, using Apple's increased memory limit (a loaded skirmish needs about 5.1 GB). Not yet verified: a real airplane-mode flight, offline skirmish save/resume, a real online match, and a one-hour session. Details: [Steam engine loop](docs/STEAM-ENGINE-LOOP.md), [device route log](docs/DEVICE-ROUTE-20260924.md). The older Simulator notes below are kept for history.

## How Steam works on the iPad

You play your own Steam copy; AgePad doesn't sell, unlock or fake anything. Steam itself decides whether your account owns the game.

1. **Sign in once.** The first time you open AgePad it shows a QR code. On your phone, open the Steam app, tap the Steam Guard shield and scan it. No phone app? Use *Sign in with your password instead*; Steam may ask for a Steam Guard code or an approval in the Steam app. AgePad keeps the sign-in in this iPad's Keychain and never stores your password. Your Steam account lists the iPad as "AgePad (iPad)".
2. **Then just tap the icon.** AgePad signs in to Steam in the background and starts the game. No Mac, Steam window or second scan is needed. The saved sign-in lasts about a year, or until you sign out or revoke it in Steam.
3. **Online:** everything works, including multiplayer (a real online match is still to be tested).
4. **Offline** (for example on a flight): with no Internet, AgePad starts Steam's own offline mode, as on a PC. Single player, skirmish and campaigns work; multiplayer is greyed out. It needs at least one earlier online sign-in on this iPad. Before you go offline, open AgePad once with Internet so Steam's copy of your library is up to date.

Things to know:

- The Steam app for iPhone/iPad is only needed to scan the code. It can't run PC or Mac games, and neither can Steam Link without a computer switched on.
- The game files (about 20 GB) come from the Mac edition in your Mac's Steam library and are copied to the iPad over a USB-C cable. See [the setup guide](docs/IPAD-SETUP.md).
- When Steam updates itself on your Mac, rerun `scripts/agepad-ipad.sh setup` with the iPad connected; AgePad takes Valve's Steam software from your Mac each build. If Valve's servers ever stop accepting the copy inside AgePad, the iPad says so and keeps working offline.
- When Steam updates the game on your Mac, the iPad keeps the version it has. Offline play is unaffected, but online matches need the current version. AgePad itself has to be updated for each new game version first; then `sync` copies only the changed files. `check` tells you when this applies.
- To sign out or switch accounts: iPad Settings → AgePad DE Probe → *Sign out of Steam*.
- Playing through your Mac's Steam (USB or Wi-Fi/Tailscale) is still available as a fallback: *Play with my Mac's Steam instead*.

## What works today

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

## What happens if I download an IPA?

There is no downloadable IPA yet. Today the app is built on a Mac from this repository and your own Steam install, then signed with your Apple developer account and installed over USB. A free Apple account's signature expires after 7 days; a paid developer account lasts a year. The Steam client engine and the game are copied from your Mac, never bundled.

The setup, all described in [the setup guide](docs/IPAD-SETUP.md):

1. On your Mac, install your owned **Mac edition** of AoE II DE through desktop Steam. Windows and Mac executables are not interchangeable.
2. Set up signing once in Xcode (the app needs Apple's larger memory limit).
3. Connect the iPad with a USB-C cable and run `scripts/agepad-ipad.sh setup`. It checks everything, builds and installs AgePad in place, and copies your game files (about 20 GB the first time; later `scripts/agepad-ipad.sh sync` copies only what a game update changed).
4. Open AgePad on the iPad and sign in to Steam once (above). From then on, tap the icon to play, online or offline.

On a new Mac, the first build also needs a one-time build package made from your game with the iPad Simulator (`check` explains; verified from scratch on 26 September, reusing the two Simulator survey results).

Game files, Steam credentials and another person's saves must not be bundled in a public IPA or repository.

## Touch controls being implemented

- One-finger tap: select / left click.
- Two-finger tap: order / right click.
- Three-finger drag: move the map (sent as a middle-button drag).
- Pinch: zoom.
- Apple Pencil: tap a unit to select, then each tap on the map is an order until a ½-second hold.
- Side shortcuts: R-click (right-click the next tap), idle villager, town center, zoom and menu.

These are the requested controls, not a claim that all gestures have passed device testing. Current validation details are in [execution status](docs/STATUS.md) and the [reorientation journal](docs/MADEIRA-REORIENTATION.md).

See the [September 14 repair findings](docs/DE-REPAIR-20260914.md) for root causes, tested fixes and remaining acceptance failures.

## Engineering reproduction

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
