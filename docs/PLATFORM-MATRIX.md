# Platform evidence

Profile: apple-singleplayer, first milestone ipad-singleplayer. Source/input identities in dependencies.lock.json and INPUTS.md.

| Target | SDK/build | Runtime | Gameplay/persistence | Physical |
|---|---|---|---|---|
| macOS ARM64 | Xcode 26.6 / SDK 26.5; engine and SFML 2.6.2 build; Mach-O ARM64/linkage inspected | original HD home and cam8 entry 0 booted; flat PNG frame/edge regression passes; native audio callback test passes; slopes/acoustic acceptance partial | select/move/gather/dropoff/train observed; house location/completion observed; house population timing/removal verified; Town Watch visibility and production cancel/refund verified; commanded combat projectile/damage/death regression passes; construction refund pending; persistence unrun | Host is not mobile evidence |
| iPad Simulator | SDK 26.5 ARM64 complete core compiles/links; IOSSIMULATOR platform audited; custom SDK FreeType | owned iPad Air11 M4/iOS26.5 real basic map/HUD, automatic simulation and nonzero audio callbacks; static texture crash fixed | touch select/build/train/research/minimap observed; explicit tap move/gather/dropoff observed; isolated commanded combat/projectile/death observed; initial green margin fixed; occupied placement rejected without cost; touch home→original tutorial first flag observed; full scenario/persistence and orientation remain pending; persistence unrun | not-applicable |
| iPad device | SDK 26.5 ARM64 complete core compiles/links; IOS platform and system linkage audited | unrun | unrun | unrun; hardware/signing not yet inspected |
| iPhone Simulator/device | SDK available; build unrun | unrun | unrun | unrun |
| Android | deferred | deferred | deferred | deferred |

No G3–G12 acceptance claimed. Native engine build/partial boot evidence exists, but row 4 reproducibility/complete execution-mode audit and G3 rendering/audio/input proof are not fully accepted. Production Metal, touch, import, lifecycle, saves, full campaigns, repeatability, clean clone and soak gates remain unmet.

2026-09-06 scenario-19: macOS ARM64 original cam8 entry0 completes through ordinary play, victory/result Return to home works, second tutorial first objective works in same process, actual exit0. Identity in scenario-19/result.json. Simulator equivalent unverified; full saves/progression absent. No gate promotion beyond this G6 subset.

G6 ipad-20: original tutorial victory, touch Return to home, and same-process second tutorial first-flag advancement verified on owned ARM64 iPad Simulator. Four allies survive; village buildings remain blue (capacity4/25 observed). Original winner log9220, second engine start9287. Evidence `docs/artifacts/2026-09-06/ipad-20/result.json` and screenshots. App externally terminated, console wrapper0 is not graceful app exit evidence; owned Simulator shutdown and zero booted devices verified. Mac and Simulator scenario/result/return subset now verified. Complete saves and independent progression remain absent; G6 stays open.
