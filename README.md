# AgePad

Age of Empires II: Definitive Edition on iPad, using the original ARM64 Mac game and an iPad compatibility layer. This is a development project, not yet a downloadable, standalone playable IPA.

## What works today

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

The September 14 Simulator repair restores missing villagers and animals by preserving source resource filename casing and resolving case-insensitive reads within the imported game-data tree. The latest candidate has demonstrated selection, a completed house, ground movement, sheep gathering, villager production and a named save/reload. Repeated movement and scout exploration also passed after a fresh launch. A 30-second run averaged 26.3 observed compositions per second, with stalls that still require investigation. Physical iPad execution remains unverified.

## What happens if I download an IPA?

There is currently no verified end-user IPA installation flow. A Simulator build cannot be installed on a physical iPad. Do not install the iPhone Steam app expecting it to supply the desktop game runtime: that is not the service used by this build.

The intended setup is:

1. On your Mac, install your owned **Mac edition** of AoE II DE through desktop Steam. Windows and Mac executables are not interchangeable for this route.
2. Run an AgePad preparation/import tool against that installation. It must verify the version and required files, preserve the source, and prepare your private game copy. An end-user importer is still to be built; current staging scripts are engineering tools.
3. Install a device-built, signed AgePad IPA on your iPad. Device packaging and launch still require validation.
4. Transfer the prepared game data to AgePad's persistent storage. The app should show import progress, available space, edition/version and any missing files. This app flow is not implemented yet.
5. Resolve Steam services before enabling Play. Current Simulator launches depend on a Mac-assisted discovery relay and a live helper. Copying files, or merely having Steam on the Mac, does not establish a self-contained iPad Steam session. This dependency must be solved or explicitly included in the supported setup.
6. Play locally on iPad. Touch controls, complete rendering, save/load, lifecycle and sustained speed must pass before this is a release feature.

Game files, Steam credentials and another person's saves must not be bundled in a public IPA or repository. Multiplayer is not verified.

## Touch controls being implemented

- One-finger tap: select / left click.
- Two-finger tap: order / right click.
- Two-finger drag: move the map.
- Pinch: zoom.
- Side shortcuts: Order, idle villager, town center, zoom and menu.

These are the requested controls, not a claim that all gestures have passed device testing. Current validation details are in [execution status](docs/STATUS.md) and the [reorientation journal](docs/MADEIRA-REORIENTATION.md).

See the [September 14 repair findings](docs/DE-REPAIR-20260914.md) for root causes, tested fixes and remaining acceptance failures.

## Engineering reproduction

### Test on this MacBook

This workflow runs the iPad build in Xcode Simulator on the Mac. It requires the
existing private runtime package and your owned Mac game installation; cloning
this repository alone does not produce a playable application.

One-command version (verifies your Steam install, stages the game data, runs the
preflight and launches):

```sh
python3 scripts/prepare-de-game.py --launch my-run-name --seconds 1800
```

Manual steps:

1. Start desktop Steam and keep it running.
2. In Xcode Simulator, boot only **AgePad G5 iPad**
   (`574671AD-6F61-4558-9528-BF946DDB760A`). Close other booted Simulators.
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

### Test on a physical iPad

**Not ready to install yet.** The September 15 inventory found no connected iPad
and no valid code-signing identity. Connect and trust the iPad in Xcode and set up
your development signing identity for device work. Those steps alone are not
sufficient: device runtime packaging, the Steam service arrangement, asset import,
and real multi-touch acceptance remain open. There is no verified IPA to download.
An independent native Mac AgePad installer is also not provided by this workflow.

Use [DE reproduction notes](docs/DE-REPRODUCE.md), [installation and service requirements](docs/DE-INSTALL-AND-ONLINE-PLAN.md), and [Mac lock diagnosis](docs/MAC-LOCK-DIAGNOSIS.md). Keep only the existing AgePad G5 iPad Simulator booted. Generated packages, logs and game data are private development artifacts.
