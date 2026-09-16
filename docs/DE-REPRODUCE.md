# Reproduce private original-DE probes

Run from the repository root. Use fresh output/evidence names. These commands do not boot devices; the runner requires exactly the designated Simulator already booted and only replaces `local.agepad.de-loader-probe`. It checks build completion and signatures before installation. The classic app is separate.

## Original executable startup

Prerequisites already recorded locally: input audit de-001, actual Simulator import survey de-006, rebuilt helper shader de-shader-006/ios16, public string constants de-010. These are ignored private inputs/evidence, not checked-in game assets.

```sh
set -e
python3 scripts/build-de-loader-probe.py \
  'ref/AoE2DE/Age Of Empires II.app' generated/DERepro.app \
  --shader generated/de-shader-006/ios16/feral.metallib
python3 scripts/build-de-boundary-probe.py \
  'ref/AoE2DE/Age Of Empires II.app' generated/DERepro.app \
  docs/artifacts/2026-09-07/de-006/simulator-result.json \
  docs/artifacts/2026-09-07/de-repro \
  --application-bootstrap --main-executable \
  --constants docs/artifacts/2026-09-07/de-010/public-constants.json
python3 scripts/stage-de-resources.py \
  'ref/AoE2DE/Age Of Empires II.app' generated/DERepro.app \
  docs/artifacts/2026-09-07/de-repro/resources.json \
  --shader generated/de-shader-006/ios16/feral.metallib
python3 scripts/run-de-probe.py generated/DERepro.app \
  docs/artifacts/2026-09-07/de-repro --mode main
```

This reproduces the candidate022 configuration, not a playable game. Candidate024 additionally has the separately retargeted original Steam library at the iOS private-framework path; it still has the same failure. Inspect logs and current-process result files, never infer success from simctl accepting a launch.

## Isolated real Steam SDK

```sh
set -e
python3 scripts/build-de-steam-probe.py \
  'ref/AoE2DE/Age Of Empires II.app' generated/DESteamRepro.app \
  docs/artifacts/2026-09-07/de-steam-repro
python3 scripts/run-de-probe.py generated/DESteamRepro.app \
  docs/artifacts/2026-09-07/de-steam-repro --mode load
```

Read `stderr.log` and the app data container's `Documents/steam-result.json`. The observed Simulator result is a real failed initialization. The equivalent native macOS control is in de-026. This SDK test intentionally does not load the game or claim multiplayer success.

For a debugger experiment the runner accepts `--debug-wait`. The observed original-game debug run exited with status 45 before the requested breakpoint, so a debugger launch is not a startup pass. No guard has been bypassed.

## Discovery and code-identity diagnostics

The current isolated Steam builder includes `MachDiscovery.h` and `CodeIdentityProbe.h`. Its result JSON records actual Mach service lookup, reachable bootstrap parents, Mac-style self lookup, static signature validation, task creation, and a read-only kernel code-status query. None replaces or changes Steam initialization. Candidate032 is the last observed runtime result.

The original-engine boundary builder now includes `SecurityTrace.m`: the traced Security functions forward to the real implementation and preserve its return value and output objects. Candidate030 demonstrates the same original startup failure with this tracing enabled.

Native comparison programs are `port/de/HostMachProbe.m` and `port/de/HostCodeIdentityProbe.m`; evidence is de-028 and de-031 respectively. Native validation success is not Simulator validation success. A development-signing experiment remains unrun because the current identity inventory is empty; do not alter system trust or report that experiment as a solution.

## Recover the currently installed private candidate (2026-09-12)

Start the existing host Steam client. Check `xcrun simctl list devices booted`;
boot only the designated G5 iPad if none is running. Then, from this repository:

```sh
python3 scripts/recover-de-session.py recovery-unique-name --seconds 3600
```

Use a fresh name each time. This uses the existing private candidate375 package
and installed app, verifies the boundary identity, surveys fresh backing GPU
metadata, restores the tested touch/graphics settings and holds temporary
keep-awake assertions. It does not reinstall the app or replace saves. The runner
closes the game and helpers at timeout; quitting/interruption also releases them.
Save through the game before that timeout. Launcher paste permission can be
rejected; select Play, skip the cinematic, then Single Player → Load Game.
A sideways initial window required Simulator rotation during this recovery.
The normal world can be left paused through MENU for inspection.

The recovery profile includes `AudioOutputCompat.dylib`. To rebuild this small
bridge from source before starting a new session:

```sh
python3 scripts/build-de-audio-output.py generated/mac-de-simulator-375/AudioOutputCompat.dylib
```

It maps the unavailable Mac default audio output to the real UIKit RemoteIO
component. The observed original-game output initializes and starts with status
zero; audible playback and interruptions still need acceptance. Fullscreen
status-bar hiding lives in `DEProbeViewController` in `port/de/LoaderProbe.m` and
requires rebuilding the AppKit boundary, not just the audio library.

This remains an engineering recovery command, not an end-user installer. Missing
unit bodies, box selection and unverified natural scrolling prevent release.
