# Playing AgePad on your iPad

AgePad runs your own copy of **Age of Empires II: Definitive Edition** (the Steam Mac version) natively on an iPad. It is the original game, not a stream or a remake. This guide covers what you need and what happens at each step.

**Current status (25 September 2026):** engineering preview. On an iPad Pro 12.9-inch (M2, 8 GB), the game reaches the menu, plays audio, loads a skirmish, and accepts touch and Apple Pencil. Long matches, save/resume and in-match frame rate are still being tested. There is no App Store or public download.

## How it works

| Part | Where it runs | What it does |
|---|---|---|
| The game (original Mac executable + your game files) | iPad | Runs the game natively on the iPad's Apple silicon |
| AgePad compatibility layer | iPad | Translates the Mac windowing, graphics, audio and input calls to iPadOS |
| Steam | **Your Mac** | Proves you own the game, exactly as when you play on the Mac |
| `scripts/agepad-ipad.sh play` | Your Mac | Starts the game on the iPad and forwards its Steam requests to the Mac's Steam over the cable/Wi-Fi link to your Mac |

**About Steam:** the game's own Steam library talks to the Steam app that is open and signed in **on your Mac**. Your password and login never go to the iPad, and nothing is faked: if Steam on the Mac is closed or signed out, the game on the iPad quits at startup. That is why the Mac must stay on with Steam open while you play, and why tapping the AgePad icon on the iPad by itself only shows a setup screen. A standalone iPad-only Steam connection does not exist yet.

## What you need

- A Mac with Apple silicon, Xcode, and Steam with **Age of Empires II: DE** installed (you must own it).
- An iPad with **8 GB of memory or more** (tested: iPad Pro 12.9-inch, M2) and about **25 GB free**.
- An Apple Developer account (free or paid) signed in to Xcode, to sign the app for your own iPad.
- A USB cable for the first setup. Later sessions can use the same network once the iPad is paired.

## Step 1 — Check what is ready

```
scripts/agepad-ipad.sh check
```

This lists each requirement with ✓ or ✗ and tells you how to fix the ✗ items. Run it again after each fix.

## Step 2 — Signing profile with the larger memory limit (once)

A loaded skirmish uses about 5.1 GB, right at iPadOS's default per-app limit, and iPadOS closes the app. AgePad therefore requests Apple's **increased memory limit** capability (on the tested iPad the limit rises from 5.1 GB to 8 GB). Xcode creates the matching profile once:

1. Open Xcode → Settings → Accounts, and make sure your team is listed.
2. Let Xcode register the app ID `local.agepad.device-de-probe` with the *Increased Memory Limit* capability. The quickest way: build any small iOS app target with that bundle ID, automatic signing and an entitlements file containing `com.apple.developer.kernel.increased-memory-limit = YES` (this is what was done for the tested iPad). Xcode stores the profile under `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.
3. Note the profile path and your signing identity (`security find-identity -v -p codesigning`).

The build step refuses a profile that lacks the capability.

## Step 3 — Build and install the app

```
AGEPAD_PROFILE="/path/to/profile.mobileprovision" \
AGEPAD_IDENTITY=<signing identity hash> \
scripts/agepad-ipad.sh build
```

This builds the compatibility layer from this repository plus the original game program from your Mac Steam copy, signs it for your iPad and installs it **in place**: game files and saves already on the iPad are kept. The build needs the engineering candidate package (`AGEPAD_CANDIDATE`); see [DE-BOOTSTRAP-20260919.md](DE-BOOTSTRAP-20260919.md) to create one on a new Mac.

## Step 4 — Copy your game files to the iPad (once, about 20 GB)

The game data (`AgeOfEmpires2Data`, ~24,900 files) is copied from your Mac Steam install into the AgePad app's own storage on the iPad (`Documents/AgeOfEmpires2Data`). It is private to your iPad and is never bundled with the app. Keep at least 25 GB free before starting; a copy that runs out of space fails partway.

On the tested iPad the copy was made with the engineering transfer tools and then checked file by file with `scripts/verify-de-device-import.c` (24,886 files, 20.37 GB, zero differences). A guided in-app import does not exist yet; `check` reports whether the files are present.

## Step 5 — Play

1. Open Steam on the Mac and stay signed in.
2. Connect and unlock the iPad.
3. Run:

```
scripts/agepad-ipad.sh play          # up to 4 hours; e.g. "play 60" for one hour
```

The Xbox intro and the menu take about two minutes to appear. Keep the Mac window open; closing it (or quitting Steam) ends the game. After a session, `scripts/agepad-ipad.sh logs` copies the game's logs to `generated/ipad-logs/`. For a bug report, run with `AGEPAD_DIAGNOSTICS=1` to add memory and thread diagnostics.

## Controls in a match

| Gesture | Action |
|---|---|
| Tap | Select (left click) |
| Drag | Selection box |
| Two-finger tap | Right click: move, gather, attack |
| Three-finger drag | Scroll the map |
| Pinch | Zoom |
| Apple Pencil tap on a unit or drag-box | Select; the next Pencil taps on the map give orders (right click) until you… |
| Apple Pencil hold (½ s) | …plain left click, which stops giving orders |
| Apple Pencil double-tap (on the Pencil's side, 2nd gen / Pro) | Deselect and stop giving orders |
| Pencil tap on the top bar or bottom panel | Normal button press |
| A Mac-style mouse or trackpad | Works as on the Mac (click, right click, scroll) |

Side buttons:

| Button | Action |
|---|---|
| R-CLICK | The next tap is a right click (useful with one finger). Shows CANCEL while waiting |
| IDLE | Next idle villager |
| TOWN | Town Center; tap again to cycle through your Town Centers |
| ZOOM + / ZOOM − | Zoom; hold to keep zooming |
| MENU | Opens the game menu; tap again to close it |

In menus, taps are always plain clicks.

**Tip:** the in-game HUD looks small on the iPad. In the game's **Options → Interface**, raise **HUD scale** and confirm; the setting is kept in your profile.

**Steam:** the name at the top right of the main menu is your Steam account, signed in through the Mac. There is nothing to sign in to on the iPad.

## Known limits

- The Mac must stay on with Steam open; no standalone iPad session yet.
- Loading a skirmish takes about a minute. The first launch after install is slower.
- Save, relaunch and resume on the iPad, sustained in-match frame rate, and multiplayer are not yet verified. The menu holds 120 fps.
- iPads with less than 8 GB of memory are not expected to fit a match; iPhones are out of scope for the same reason.
- The player score list can overlap the top of the minimap at the default HUD scale; under investigation.

