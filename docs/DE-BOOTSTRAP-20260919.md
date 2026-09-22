# Rebuilding the Simulator candidate from your own game — 2026-09-19

Until today the runnable candidate could only be assembled on this Mac by hand.
`scripts/bootstrap-de-simulator.py` now rebuilds one from tracked sources plus your
owned Mac edition of AoE II DE. This note records what it does, what was
verified, and the one piece that is still not reproduced.

## Prerequisites

Xcode with an iOS 26.5 Simulator runtime; desktop Steam signed in with the Mac
edition installed (build `478570.102902`); the designated Simulator device. The
scripts identify the device as

```sh
export AGEPAD_SIMULATOR_UDID=$(python3 - <<'PY'
import json,subprocess
b=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','-j']))
print([d['udid'] for g in b['devices'].values() for d in g][0])
PY
)
```

or create one with `xcrun simctl create "AgePad G5 iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-26-5`.
The launch-path scripts read that variable and fall back to the UDID this Mac
uses; the older references embedded in the historical documents are not updated.

## One command

```sh
python3 scripts/bootstrap-de-simulator.py generated/de-candidate-YYYYMMDD
```

Stages, in order, each resumable with `--only <stage>`:

| Stage | What it does | Source |
| --- | --- | --- |
| `steam` | verify the Steam install, version and hashes | your game |
| `audit` | inventory the original app's imports | `audit-de-bundle.py` |
| `shader` | retarget the supplied Metal IR | `rebuild-de-shaders.py` |
| `loader-probe` | build the import-survey probe | `build-de-loader-probe.py` |
| `survey` | install, run and harvest the platform survey | the probe |
| `boundary-1` | generate the boundary libraries (no constants yet) | `build-de-boundary-probe.py` |
| `constants` | read the real public Mac string constants | `HostConstants.m` |
| `boundary-2` | regenerate the boundary libraries with those constants | `build-de-boundary-probe.py` |
| `resources` | stage resources and the retargeted shader | `stage-de-resources.py` |
| `steam-module` | translate the supplied Steam module into the app | `prepare-de-load-image.py` |
| `runtime` | build the launch-injected libraries and host relay | `build-de-injected-runtime.py` |
| `probe` | build the Simulator-side route probe | `BootstrapRoutesProbe.c` |
| `ipc-helper` | build the Steam IPC helper | `build-de-ipc-helper.py` |
| `install` | install the candidate on the designated Simulator | `simctl` |
| `manifest` | record app container, boundary identity, package layout | - |

Then stage the game data next to the installed app (this wipes and rewrites it,
because `simctl install` replaces the whole bundle container):

```sh
python3 scripts/prepare-de-game.py
```

## Verified on 2026-09-19

- Audit and shader retarget complete from the Steam install.
- Live platform survey: 63 entries, 53 already loadable on iOS.
- Boundary generation produced the same 17 `DEBoundary_*.dylib` names as the
  candidate that was in use, plus `DEOriginalGame`, `EngineEntry.json`,
  `BoundaryDiagnostic.json` and the `Vendor_*` images.
- Public constants: 31 measured values read from the host frameworks (the value
  count matches the hand-audited `public-constants.json`).
- Injected runtime: symbol sets identical to the shipped binaries apart from
  ARC/optimizer codegen; the rebuilt route probe prints exactly the same JSON as
  the shipped one.
- Install and data staging pass; `check-de-install.py` reports all local checks
  passing.

Evidence: `generated/de-bootstrap-d/` (bootstrap log, survey, constants,
boundary artifacts, `bootstrap.json`) and `generated/de-bootstrap-d/package/`.

## The Steam client chain (reproduced 2026-09-21)

The engine reaches menus by `dlopen`ing bare names such as `steamclient.dylib`,
`libaudio.dylib`, `libtier0_s.dylib` and `libvstdlib_s.dylib`, which it finds
through the relay's `DYLD_LIBRARY_PATH=package/game-client`. That directory is
built by `scripts/build-de-steam-client-boundary.py` from the *Steam client's*
Frameworks plus an audited client dependency graph that no script in the tree
generates.

Observed without it: the rebuilt candidate loads, initialises Metal, builds the
menu model, then exits — `result.json` records `end_reason: game-exited` after
4.4 s, and `game.stderr` ends at `DE_MENU_MODEL_CREATED` with no fatal signal.
With `game-client/*.dylib` supplied from the existing package, the same rebuilt
candidate renders the launcher screen and stays up (verified 2026-09-19;
`client-chain-test/`).

Next step for full reproduction: generate that client dependency graph from
`otool -L` plus Simulator-SDK presence checks over the Steam client's
`Contents/Frameworks`, run `build-de-steam-client-boundary.py` into
`package/game-client/`, and add the stage to the bootstrap. The bootstrap now
records `client_chain_present` in `package.json` so an incomplete package is not
mistaken for a launchable one.

## Rights

This rebuilds a private engineering candidate from files you own. It does not
change [RIGHTS-STATUS.md](RIGHTS-STATUS.md): publication is not approved, and
distributing this pipeline or its outputs still needs a rights decision.


## Reproduced: the Steam client chain (2026-09-21)

The `package/game-client/` directory - the Steam images the engine loads by bare
name through `DYLD_LIBRARY_PATH` - is now rebuilt too: `scripts/audit-de-steam-client.py`
derives the dependency graph from the Steam client you already have,
`port/de/LibrarySymbolSurvey.m` is built for the Simulator and run there to learn
what those images genuinely lack, and `build-de-steam-client-boundary.py`
translates them. Two defects had to be fixed first:

- Load commands carry macOS framework paths (`...framework/Versions/A/...`) which
do not resolve inside the Simulator. Every symbol therefore looked missing and
frameworks that exist on iOS (Foundation, Security, CFNetwork) received bogus
abort boundaries. Surveying the iOS form dropped the reported gap from 138 to 38
missing exports - the same number the project's earlier notes recorded - and
produced exactly the boundary set the working chain has.
- Client boundaries must not declare a class the Simulator already has
(`NSUserDefaults`, `NSWindow`), and `DE_DIAGNOSTIC_CLASS` emits a class and its
metaclass together, so metaclass symbols are never emitted separately.

## Acceptance, 2026-09-21

A complete bootstrap of a fresh directory - every artifact rebuilt from tracked
sources plus the owned Steam install - followed by data staging and a launch:

```
"end_reason": "observation-expired",
"alive_after_observation": true,
"observation_ended_after_seconds": 150.07
```

The candidate rendered the launcher screen
(`generated/de-candidate-20260921/package/accept-1/acceptance-landscape.png`) and
survived the whole observation window; the runner then stopped the game and
released the helper and keep-awake assertion. `otool -L` equality against the
previously working chain holds for all seven translated images, and the boundary
set is identical.

Still outside this reproduction: signing credentials for a device build, the
host-assisted Steam session (which the IPA goal has to replace or disclose), and
the publication decision in RIGHTS-STATUS.md.


## Verified from a clean clone, 2026-09-21

A `git clone` with no `generated/` directory ran the full bootstrap, staged the
game data, passed its own preflight and launched:
`end_reason: observation-expired`, `alive_after_observation: true`, 130.1 s with
the launcher rendered. Two resolution defects only appeared there and are fixed:
package discovery matched on a name instead of the `game-client-appkit.json`
marker, and the session runner defaulted its probe to this Mac's private path.

On a new machine: `python3 scripts/create-de-simulator.py`, export the
`AGEPAD_SIMULATOR_UDID` line it prints, then bootstrap. `scripts/de_device.py`
resolves both the device and the package (`--package` overrides; the private
package wins if present).
