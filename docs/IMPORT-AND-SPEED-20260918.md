# September 18: game import flow and simulation-speed check

## Import flow now exists and passed a clean run

`scripts/prepare-de-game.py` is the "add the game" command for the Mac test flow.
It locates the Steam Mac installation (default Steam library path, or `--source`),
verifies it is the exact build the runtime was adapted for (bundle version
478570.102902, executable and libsteam_api SHA-256), checks the four data
directories, boots the designated Simulator if nothing is booted, stages the
19 GB data tree next to the installed app with original filename casing and
per-file hash verification (via `stage-de-simulator-adjacent.py`), runs the
launch preflight, and with `--launch NAME` starts the session.

Clean test: moved the previously staged data and Frameworks aside, ran the
command from scratch against the live Steam installation. 41 s wall time;
13,917 resource and 6,803 widgetui files verified; launch, main menu, new
skirmish and load of a prior save all worked on the freshly imported data.
Your Steam copy is byte-identical to the reference build, so the checks are
exact rather than heuristic.

Not covered: physical-iPad transfer, persistent app-container storage, or a
standalone Steam session. This is the engineering/Mac flow made one command.

## Is the game running at the right speed? Mostly, and it depends on host load

DE's Normal game speed advances the in-game clock 1.7× real time. Two
measurements, each a fresh skirmish left untouched between Start Game and
MENU → Quit, reading the statistics-screen timer:

| Host load | Real seconds | Game clock | Ratio | Of normal |
| --- | --- | --- | --- | --- |
| 35 (a runaway Simulator `mediaanalysisd` at 92% CPU plus a foreign clang build) | 261 | 5:12 (312 s) | 1.20× | 70% |
| 17 (that daemon killed) | 79 | 1:53 (113 s) | 1.43× | 84% |

The Simulator process itself was at 15–26% CPU in both runs, so the game is
starved rather than saturated. Composition throughput under the lower load was
32.3/s over 60 s (min 21, max 39), up from 21/s earlier today. The simulation
slows proportionally when the host is contended; on an idle host it is likely
at or near the 1.7× target, but that has not been measured because this Mac
has not been idle. Gathering during the 3-minute AGEPADPLAY914 window
advanced food 127→221 and wood 225→225 (no lumberjack assigned), consistent
with two shepherds at normal rates for that elapsed game time.

Conclusion: the engine is simulating correctly; wall-clock speed is limited by
CPU contention on this Mac. A device measurement is the next real data point.

## Also checked

- **Native Mac control** at the same version still refuses automated menu
  clicks (first click hovers, second click also only hovers), so the side-by-side
  native baseline remains a manual step. The game's own log confirms Steam
  online and network initialized on both native and Simulator.
- **Xbox Network sign-in** on Simulator: click dispatched, no window request,
  no log line from the game or XAL. XAL builds its login UI from
  `xal_web_kit_window_controller_mac.nib` via `NSWindowController`, which our
  AppKit boundary registers only as a fail-fast diagnostic class — but the abort
  never fires, so XAL is not even reaching that point. Likely gated on a
  precondition (Xbox Live init state) we have not traced. Still open.
- **App icon:** `scripts/apply-de-app-icon.py` writes the game's own icon and
  "Age of Empires II" display name into the installed bundle. SpringBoard did
  not refresh from an in-place edit; a reinstall or device reboot is required
  to see it. Left as is for now.
