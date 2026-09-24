# Physical iPad scout — 24 September 2026

## Result

Chris's wired iPad Pro 12.9-inch (6th generation), iPadOS 26.7 (23H24), was paired, in Developer Mode, and reachable through CoreDevice. A new `local.agepad.device-scout` app was built for the **iOS device** platform, signed with the local Apple Development identity and a provisioning profile covering the device, installed with `devicectl`, and launched. `devicectl` captured a 2732×2048 screenshot showing the native scout UI. The app process remained present when checked. No existing AgePad bundle was installed, so no AgePad saves or data were replaced.

This is **hardware deployment and rendering proof**, not Age of Empires gameplay. The installed scout contains no game executable, assets, Steam service, importer, or save system. Its tap and pinch controls are visible; physical finger input was not observed in this run. Private screenshot and exact executable digest are in ignored `generated/device-scout-20260924b/`.

## Reproduce the scout on this Mac

From the repo root, with the iPad connected and unlocked, set `AGEPAD_PROFILE`, `AGEPAD_SIGNING_IDENTITY`, and `AGEPAD_DEVICE_UDID` to your own development profile, certificate SHA-1 and device ID:

```sh
python3 scripts/build-device-scout.py \
  --output generated/device-scout-local/AgePadScout.app \
  --profile "$AGEPAD_PROFILE" \
  --identity "$AGEPAD_SIGNING_IDENTITY"
xcrun devicectl device install app --device "$AGEPAD_DEVICE_UDID" generated/device-scout-local/AgePadScout.app
xcrun devicectl device process launch --device "$AGEPAD_DEVICE_UDID" local.agepad.device-scout
xcrun devicectl device capture screenshot --device "$AGEPAD_DEVICE_UDID" --destination generated/device-scout-local/hardware.png
```

Choose a fresh output directory each run. The scout uses a separate bundle ID, leaving any later game app and its data independent. `codesign --verify --deep --strict` passed before install; `vtool -show-build` reported platform `IOS`, minimum 17.0, SDK 27.0.

## Why the Steam DE game cannot be copied to this iPad yet

The playable candidate in `generated/de-candidate-20260924-responder/` is an **iOS Simulator** adaptation of the owned Mac ARM64 Steam build. `vtool -show-build` identifies `DEOriginalGame`, `Engine.dylib`, `DELoaderProbe`, `DEBoundary_AppKit.dylib`, and the adapted Steam API image as `IOSSIMULATOR`. Device iPadOS requires `IOS` code signatures and platform-compatible images. Merely resigning the Simulator app does not change that. Its launch also depends on `simctl` environment injection, a Mac-hosted Steam path relay and IPC helper, and game data staged beside the Simulator app. The current device builder produced no device game app or IPA.

The legacy device boundary script expected three recorded link commands absent from the fresh bootstrap. It now checks all 27 generated boundary sources against the device SDK from the fresh package; this run found **0 syntax failures** (`generated/de-device-probe-20260924b/device-compile-result.json`). This narrows source portability but does not link the libraries, adapt and sign the original engine/client chain for hardware, or establish Steam execution on-device.

The alternative native classic/HD route is also not ready to install from this checkout: its pinned `ref/` and `worktrees/` sources and device output are absent here, and the local Steam library contains AoE2DE rather than the Windows HD/2013 input that route requires. The PRD keeps that route distinct from this Mac DE prototype.

## Product and UX findings

1. A first-run screen must identify the exact edition and the source computer, then show what AgePad can import. The current game candidate has no on-device importer; Steam being installed on the Mac is insufficient for a self-contained iPad session.
2. The install path is feasible on this iPad. The next playable candidate needs an `IOS` binary and signed dependency chain, persistent game storage in the app container, and a tested Steam strategy. Only then should the UI offer **Play**.
3. The hardware scout uses plain diagnostic UI and clearly labels itself. It must not be presented as the game. Future game controls should use the classic/HD visual reference and pass real finger tap, two-finger order/pan, pinch, hold, save/relaunch, audio and sustained performance checks.

## Next technical gate

Build the actual DE engine and every required image for `iphoneos`, then audit their Mach-O platform and dependencies, sign a separate device candidate, install in place, and launch it without `SIMCTL_CHILD_*` paths. A device-signed shell alone is not that gate. If the Mac Steam service cannot be made available legitimately and reliably to the device, the setup must state that before importing ~19 GB of game data.
