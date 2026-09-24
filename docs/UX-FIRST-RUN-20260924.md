# First-run iPad Simulator audit — 24 September 2026

## Scope and result

This was a hands-on pass through the **Mac Steam Definitive Edition prototype** on the AgePad G5 iPad Simulator (iPad Air 11-inch M4, iOS 26.5). The original [PRD](AgePad-PRD.md) calls for a classic/HD native iPad product first and treats DE as a later branch. This prototype is useful evidence for the DE route, but does not complete or replace the PRD's classic/HD baseline.

The Mac already had desktop Steam and its Mac edition of AoE II DE. Steam updated the game during the first build. The successful candidate used game bundle version `488492.107976`, executable SHA-256 `b40e57e9d77877a59c76f73b515635dfc2d9d39db7d1026d185b06da9f6dfa2b`, and `libsteam_api.dylib` SHA-256 `7d4991c162d283fef829c287217767326649f02fdcb57e4366e441255ea87d91`. Its private package was built under `generated/de-candidate-20260924-fullscreen/`, installed, and staged with the local ~19 GB game data. The preflight reported Ready.

**Observed:** original launcher → Play → DE main menu → Single Player → Skirmish → live map. A tap selected a villager; Order then a ground tap moved it; the Zoom + side control changed map scale. The first candidate exited on an AppKit `moveRight:` selector probe. The rebuilt `generated/de-candidate-20260924-responder/` candidate survived a 600-second timed observation, including a second skirmish and a directional key input, with no new unsupported-selector entry. The runner stopped that game at its planned deadline. This session does not establish scenario completion, saves, performance, real multitouch, or physical iPad play.

## First-run journey

| Step | What appeared | Health and needed change |
|---|---|
| 1. Obtain data | Desktop Steam Mac AoE II DE was already installed. AgePad discovered it through a Python CLI, not the iPad UI. | **Blocked for an end user.** Build an explicit Mac preparation/import assistant that detects the owned install, shows edition/version/size and exact next action. A Steam connection in the iPad app does not exist. |
| 2. Build and import | The bootstrap produced a Simulator app; `prepare-de-game.py` verified hashes, copied ~19 GB beside it, then ran preflight. Steam updated midway through the first build, so an old candidate was rejected. | **Engineering path works, product path missing.** Keep the exact-version and installed-package checks. Show copy progress, available space, version mismatch and retry inside a guided flow. |
| 3. Home screen | A game-art icon appeared. The label initially read `AgeofEmpiresII...` because localized `InfoPlist.strings` overrode the main plist. The installer now updates that name too; the reinstalled icon visibly reads `AgePad`. A separate old `DE Loader Probe` icon was still present on this test Simulator. | **Improved.** The installed candidate has the right icon and label. A clean end-user package should not install the engineering probe icon. |
| 4. Launch | The game opened in portrait as a small landscape rectangle, with a Usage Statistics choice. | **Poor tablet fit.** Present an AgePad setup screen in the current orientation and explain privacy choices in iPad language. |
| 5. Desktop notices | Magic Mouse/Trackpad middle-button, macOS function-key, and active-mod notices appeared before Play. | **Confusing.** Suppress or replace irrelevant desktop instructions; preserve notices that genuinely affect this build and make their action clear. |
| 6. Launcher and Play | The original Mac launcher appeared; Play loaded the DE menu. An absent optional Enhanced Graphics Pack warning and a DLC News popup followed. | **Playable but noisy.** Avoid prompting about optional content the importer never required. Put game launch status and missing mandatory assets first. |
| 7. Main menu | The original DE menu was tappable and legible in landscape, with black letterboxing and a right-side Order/Idle/Town/Zoom/Menu strip even though no game was active. | **Partial.** Hide gameplay shortcuts outside gameplay; adapt menu scaling to iPad safe area and touch size. |
| 8. Skirmish setup | Single Player → Skirmish opened the original setup. Defaults on this Steam profile were Death Match, Imperial Age, five players. | **Partial.** It functioned, but settings and small dropdowns are dense for fingers. A new user should see a simple suggested first game without silently modifying their Steam preferences. |
| 9. Gameplay | Map, units, HUD and minimap rendered. A villager selection, Order + ground movement, and Zoom + worked. | **Promising Simulator slice.** Test two-finger order, drag, pinch, double tap, long press, economy/combat/save, and sustained frame pacing with real fingers on a device. The game content is still letterboxed and the HUD is dense. |
| 10. Exit/stability | The first candidate exited during the skirmish after an unsupported `NSView moveRight:` selector check. A guarded responder probe fixed that path; the rebuilt game stayed alive until the 600-second runner deadline. The in-game pause menu opened and showed Save Game. | **Partial.** Ten minutes is a useful smoke pass, not a stability soak. Saving and reloading were not completed before the runner deadline. |

Private screenshots are in ignored `generated/de-candidate-20260924-security-anchor/ux-audit/` (portrait consent, mouse and keyboard notices, mod notice, launcher), `generated/de-candidate-20260924-fullscreen/ux-audit/` (skirmish setup and live map), and `generated/de-candidate-20260924-responder/home-name.png` (corrected label). They contain game art and profile details and should not be added to the public repository.

## Touch and accessibility notes

The source maps one-finger tap to select, two-finger tap to order, two-finger drag to map pan, and pinch to zoom. The side Order button supplies a one-pointer fallback, and its selected state changes to Cancel. This pass visibly proved taps, that fallback order, and Zoom +. Computer use could not generate two simultaneous fingers, so multitouch claims remain untested. No double-tap or long-press game action has been validated. The original game canvas exposes only the side buttons in the accessibility tree; menu text and objects did not appear as accessible controls. Text and targets are especially small in portrait.

## Physical iPad gate

Chris's iPad Pro (12.9-inch, 6th generation) was paired and connected on iPadOS 26.7, and development signing identities were available. The current product is a Simulator-specific app with a Mac-assisted Steam discovery relay and data staged in a Simulator bundle container. The existing device compile probe was attempted against the new package and stopped before compiling because it expects the retired package's `appkit-build-command.json`, which the fresh bootstrap does not emit. There is no verified device-architecture runtime, signed IPA, on-device import/storage flow, or standalone Steam-service path. Nothing was installed on the physical iPad. Next device work begins by making the device-SDK builder consume the fresh package, then exact binary/signing audit, preservation-safe install and on-device testing of touch, saves, lifecycle and performance.

## Reproduce this candidate

Only one Simulator may be booted. On this Mac the active AgePad G5 iPad has UDID `3B66F77C-EDAC-419F-9B75-8694A525B19D`; older documentation contains a retired UDID. From the repository:

```sh
export AGEPAD_SIMULATOR_UDID=3B66F77C-EDAC-419F-9B75-8694A525B19D
python3 scripts/bootstrap-de-simulator.py generated/de-candidate-NEW
python3 scripts/prepare-de-game.py
python3 scripts/recover-de-session.py new-run-name --seconds 1800 --package generated/de-candidate-NEW/package
```

Steam must be running. The bootstrap output directory and run name must be new. A Steam game update requires a fresh candidate built against that exact update. The importer stages owned data after installing the app; reinstalling the Simulator app requires restaging.
