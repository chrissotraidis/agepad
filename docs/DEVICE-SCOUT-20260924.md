# Physical iPad scout — 24 September 2026

## Result

Chris's wired iPad Pro 12.9-inch (6th generation), iPadOS 26.7 (23H24), was paired, in Developer Mode, and reachable through CoreDevice. A new `local.agepad.device-scout` app was built for the **iOS device** platform, signed with the local Apple Development identity and a provisioning profile covering the device, installed with `devicectl`, and launched. `devicectl` captured a 2732×2048 screenshot showing the native scout UI. The app process remained present when checked. No existing AgePad bundle was installed, so no AgePad saves or data were replaced.

This is **hardware deployment and rendering proof**, not Age of Empires gameplay. The installed scout contains no game executable, assets, Steam service, importer, or save system. Chris tapped **Test tap** and pinched the physical screen; the live QuickTime preview showed `Taps: 1` and `Pinch scale: 0.81`. A second CoreDevice screenshot captured those values. This verifies touch delivery in the native scout, not game commands or pinch zoom inside Age of Empires. Private screenshots and exact executable digest are in ignored `generated/device-scout-20260924b/`.

Xcode 27 Device Hub's **View Screen** refused this iPad because that viewer requires iPadOS 27 and CoreDevice still reports 26.7, even after reconnecting. QuickTime Player's wired **Movie Recording → Screen → Chris's iPad Pro** route succeeded: its live preview showed this app and the physical touch results. Recording was not started. Device Hub's restriction therefore does not prevent local visual inspection through QuickTime.

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

The playable candidate in `generated/de-candidate-20260924-responder/` is an **iOS Simulator** adaptation of the owned Mac ARM64 Steam build. `vtool -show-build` identifies `DEOriginalGame`, `Engine.dylib`, `DELoaderProbe`, `DEBoundary_AppKit.dylib`, and the adapted Steam API image as `IOSSIMULATOR`. Device iPadOS requires `IOS` code signatures and platform-compatible images. Merely resigning the Simulator app does not change that. Its Simulator launch also depends on `simctl` environment injection, a Mac-hosted Steam path relay and IPC helper, and game data staged beside the Simulator app.

The legacy device boundary script expected three recorded link commands absent from the fresh bootstrap. It now checks all 27 generated boundary sources against the device SDK and links the 18 generated engine boundary libraries as `IOS` images from the fresh package. This run found **0 source or link failures** (`generated/de-device-probe-20260924d/`). The first on-device DE launch then exposed a missing `NSColor` Objective-C class alias. The device linker now emits the same alias as the Simulator builder, and the next launch passed that point.

### Original-engine device launch probe

`scripts/prepare-de-device-probe.py` creates a separate, private `local.agepad.device-de-probe` bundle from the Simulator package. It retargets and signs 64 Mach-O images for `IOS`, uses the device-linked boundary libraries, and embeds a matching development provisioning profile. The output is a **launch diagnostic**, not an end-user app; it contains no imported ~19 GB game-data tree and no on-device Steam service. A generated candidate was installed on the iPad without replacing the scout or any other app.

Only the 18 engine boundary libraries are rebuilt from generated source; the original engine and remaining client images are metadata-retargeted ARM64 binaries in this experiment. This does not establish their iPadOS compatibility. The probe removes the original localized display-name override, and CoreDevice now lists it as **AgePad DE Probe**, distinct from **AgePad Scout**.

To repeat that bounded probe from a fresh Simulator candidate (using the same three local signing variables above), choose fresh output names:

```sh
python3 scripts/build-de-device-runtime.py generated/device-boundaries-local \
  --package generated/de-candidate-20260924-responder/package
python3 scripts/prepare-de-device-probe.py \
  --candidate-root generated/de-candidate-20260924-responder \
  --boundary generated/device-boundaries-local \
  --output generated/device-probe-local/AgePadDeviceProbe.app \
  --profile "$AGEPAD_PROFILE" --identity "$AGEPAD_SIGNING_IDENTITY"
xcrun devicectl device install app --device "$AGEPAD_DEVICE_UDID" generated/device-probe-local/AgePadDeviceProbe.app
xcrun devicectl device process launch --console --device "$AGEPAD_DEVICE_UDID" local.agepad.device-de-probe
```

The corrected candidate began executing the original game, handed off to UIKit and printed its platform survey with `simulator: 0` and iPadOS 26.7. It then exited with `EXC_BAD_ACCESS / SIGSEGV` on the main thread. The preserved device crash report records a null-address read in `DEOriginalGame` at image offset `0x505fc`, reached from a delayed main-thread callback. The device console ended after `DE_RUNNING_APPLICATION_QUERY local.agepad.device-de-probe`. No DE menu, map or gameplay appeared; QuickTime returned to the iPad Home screen. The missing game data and Steam path remain unresolved; the crash report alone does not establish which prerequisite caused the null read. Private console and crash evidence are under ignored `generated/de-device-candidate-20260924/`.

The device crash reports were copied with `idevicecrashreport --keep --filter DEOriginalGame`, preserving the originals on the iPad. The first two reports documented the `NSColor` dynamic-loader failure; the later two documented the null read. This is why a successful `devicectl process launch` response cannot be treated as game startup proof.

### Device setup gate and first-run UX check

The null read occurs immediately after a virtual call returns a null object in the original game at image offset `0x505fc`. The call is in the game's Steam-related startup region; its argument resolves to `SteamUtils` callback context in the executable's indirect symbols. This narrows the investigation but does not prove a single root cause. The Simulator continues from the same running-application query into `libsteam_api.dylib` loading and live Steam initialization. The device bundle has neither the corresponding Mac Steam service path nor imported game data. A null guard in the retail executable would not provide those prerequisites.

`scripts/prepare-de-device-probe.py` now places a `DeviceSetupGate` marker in this diagnostic bundle. The UIKit host checks for it before invoking the original launch callback, then shows actual setup state. This gate is device-probe specific; it does not change the playable Simulator candidate. A fresh signed 64-image package was installed **in place** over the existing probe on the same iPad. Its console printed `DE_DEVICE_SETUP_GATE data_folder_present=0 steam_connection=unavailable original_launch=skipped`; the game process remained alive and a 2732×2048 CoreDevice screenshot showed the setup page. No game data was transferred, and the scout remained installed. The evidence is under ignored `generated/de-device-candidate-20260924b/`; the accepted screen is also [in the repo](images/device-setup-20260924.png).

UX audit of the actual hardware first screen:

1. **Open AgePad DE Probe — stable, but blocked.** The page names the exact DE edition and says the game cannot start. It reports the absent data folder and unavailable Steam connection, so the user no longer sees an unexplained return to Home. The page offers no import or connect action because neither path is implemented. Its large empty lower area and plain dark styling do not match the original DE launcher reference; this is a diagnostic screen, not an accepted product onboarding design.
2. **Next action — limited.** It directs testing to the existing Mac-assisted Simulator. There is currently no actionable on-iPad path to Play. A future setup flow must verify the precise source edition and files, show space/progress during import, test a legitimate Steam connection, and enable Play only after those checks pass.

The visible text has clear size and contrast in the screenshot. VoiceOver order, Dynamic Type scaling, rotation, and reachability by touch were not tested on this page. The screenshot proves this one state, not an end-to-end importer or game control flow.

The active target is AoE II **Definitive Edition** from the installed Steam copy. The older PRD's classic/HD route does not meet Chris's current requirement.

## Product and UX findings

1. A first-run screen must identify the exact edition and the source computer, then show what AgePad can import. The current game candidate has no on-device importer; Steam being installed on the Mac is insufficient for a self-contained iPad session.
2. The install path is feasible on this iPad. The boundary libraries link for `IOS`, and the original engine reaches UIKit in a signed device probe. The next playable candidate needs the null crash resolved, persistent game storage in the app container, and a tested Steam strategy. Only then should the UI offer **Play**.
3. The hardware scout uses plain diagnostic UI and clearly labels itself. It must not be presented as the game. Future game controls should use the DE visual reference and pass real finger tap, two-finger order/pan, pinch, hold, save/relaunch, audio and sustained performance checks.

## Next technical gate

Resolve the original DE engine's device Steam startup with a legitimate connection and exact dependency state, then launch past the gate without `SIMCTL_CHILD_*` paths. Design a supported Mac-to-iPad DE game-data import before transferring ~19 GB or enabling Play. The current setup page states that the Steam path is unavailable before asking for data import.

The follow-up [physical execution route check](DEVICE-ROUTE-20260924.md) tested the Simulator Steam helper's process and Mach-service assumptions directly on hardware. Both failed under the current iPad app sandbox. Chris clarified that the active product must use **Definitive Edition**, so the next investigation remains DE-specific.
