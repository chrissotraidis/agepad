# Release readiness

Private-only. No source/binary publication authorized. No complete technical profile, mobile build, physical acceptance or release rights decision exists. Local ad-hoc signing of Mac probe bundles uses no account or distribution identity and is not publication approval.

freeaoe source carries GPLv3-or-later notices; dependency/license inventory and exact artifact distribution decisions remain open. Keep original/converted assets, private profiles/evidence and executable input out of the integration repository. Each future source/package candidate needs its own audit and explicit publication approval.

## Recovery qualification — 2026-09-12 evening

Status: **not ready for public release**. The existing original Mac DE engine
runs again on the designated iPad Simulator. No new publication or signing was
performed. Recovery is now explicit in `scripts/recover-de-session.py`; it does
not depend on remembered experimental shell flags or rebuild game libraries.

| Gate | Current evidence | Required before release |
| --- | --- | --- |
| Menu clicks and loading | Single Player → Load Game → autosave accepted first taps in repeated fresh runs | Broader repeatability and physical touch testing |
| Selection and orders | Town center direct tap; idle-villager shortcut; Order + ground moved ring to destination | Fix box selection and test rapid/interrupted gestures |
| Camera and zoom | Minimap tap pans; Zoom +/− shortcuts change world scale | Actual two-finger pan/pinch, mouse wheel and trackpad acceptance |
| Rendering | Terrain, buildings, HUD and fog render | Unit bodies still invisible: release blocker |
| Audio | Mac default-output failure identified; RemoteIO bridge initializes/starts in the real game | Confirm audible music/effects and interruption/resume on target device |
| Input accessibility | Shortcut labels exposed; original game controls mostly absent from AX; fullscreen status-bar overlap fixed and screenshot verified | Remove duplicate shortcut AX elements; device target-size and assistive-input checks; save-name text entry fails under automation |
| Host stability | Bounded keep-awake; quieter launch; game/helper cleanup tested | Establish cause of desktop freeze; sustained session and thermal/memory qualification |
| Physical install | Simulator execution only | Signed device build, installation/import/lifecycle/save qualification |
| Steam dependency | Genuine host Steam and local helper required | Supported end-user service/setup flow |
| Distribution | Source safety check passes | Exact artifact, dependency/license and asset-exclusion review; public packaging remains absent |

A 30-second stationary-world observation counted 877 displayed composition
completions (29.23/s), zero reported drops. This is Simulator composition,
not physical FPS. The indirect-scroll recognizer experiment produced no incoming
wheel dispatch under automation, with or without pointer capture; it was reverted
from the live candidate and retained only as private diagnostic material.

Private evidence: `generated/recovery-audit-20260912/REPORT.md` and
`generated/mac-de-simulator-375/recovery-20260912-*`. Test runner expiration now
stops the owned game before removing helper/keep-awake coverage, and helper failure
ends the observation. A real five-second expiration check confirmed game and
helper gone, relay exited and discovery absent. A separate SIGTERM check confirmed
owned processes stopped. Do not leave a renderer orphaned as a purported soak.

Rendering/audio follow-up evidence: `generated/render-audio-20260912/REPORT.md`.
The 400 successful observed sprite parses contain no villager idle/walk records;
this is a diagnostic boundary, not a completed rendering repair. The unmodified
Mac comparison did not reach gameplay under automated input. Native graphics
parity remains unqualified.
