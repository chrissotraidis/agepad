# Local Windows DE compatibility qualification

Research decision, 8 September 2026. User constraints: the game executes on iPad; no streaming and no publisher-backed port. This is a proposed next experiment sequence, not a runtime result or a claim that DE multiplayer works.

## Recommendation

Qualify an existing iOS Wine + FEX + DXMT stack against the real Windows Steam client and Windows DE before committing to further Mac adaptation. Keep the Mac probes as reference work. A Windows target is the direct route to testing compatibility with the Windows retail multiplayer population; the official Mac build has a separate population.

## New evidence

- UTM 5.0.5 beta, released 2 September, explicitly adds iOS DirectX 11 through DXMT. The previous answer based on its July blog was stale. Experimental driver support is not an AoE test. JIT-only sideloading and old-firmware hypervisor configurations must be measured separately. [Release](https://github.com/utmapp/UTM/releases/tag/v5.0.5), [installation](https://docs.getutm.app/installation/ios/).
- Madeira (formerly willfaust/Mythic; unrelated to MythicApp's Mac launcher) combines ARM64EC Wine, FEX and DXMT within a single iOS process. Its README reports playable Windows titles on a non-jailbroken iPhone, with sideloading and debugger-enabled JIT. These are upstream reports, not reproduced AgePad results. Snapshot: `97e2ce26e6dc9e4a38976f3b5deb9272d64558eb`. [README](https://github.com/willfaust/Madeira/blob/97e2ce26e6dc9e4a38976f3b5deb9272d64558eb/README.md).
- Madeira's Steam handoff describes a rendered login UI but unresolved client crashes, rendering defects and login/network failures. It is dated 5 August, so verify the current code before assuming each issue remains. Some architecture notes contradict one another and include speculative performance projections; do not use them as measured capability. [Steam handoff](https://github.com/willfaust/Madeira/blob/97e2ce26e6dc9e4a38976f3b5deb9272d64558eb/STEAM_CEF_HANDOFF.md).
- Juice offers a separate iOS Wine/FEX implementation. Its README reports x64 Chocolate Doom gameplay, but the audited target requires a rootless jailbreak and TrollStore. It is a reference implementation, not evidence for an ordinary-device DE product. [Juice](https://github.com/ExoCore-Kernel/Juice).

## Bounded gates

1. Audit Madeira's build graph, fork revisions, process model, Steam code changes and missing dependencies. Reproduce a small x64 program and D3D11 render test in our designated Simulator where supported. No second Simulator. Never substitute a macOS process for an iOS success.
2. Repeat the small execution/graphics tests on the target physical iPad early. Record model, RAM, OS, signing/JIT setup, memory use and sustained frame times. Simulator FPS does not establish device FPS or JIT availability.
3. Qualify the real Steam client locally: successful actual login, persistent session, entitled DE installation and real SDK initialization. Record actual failures and distinguish client/browser/network/runtime faults. A login screen or an imported depot is not a pass. No host service helper as the standalone acceptance result.
4. Launch the current Windows DE installation with original simulation and network code. Complete a small AI skirmish; record real game speed and frame-time distribution. The existing Mac DE executable and HD executable are not substitutes for the Windows DE input.
5. Complete a private online match against an untouched matching Windows retail client. Check desyncs, disconnects and sustained simulation speed; then test larger battles. Move this gate before substantial touch polish.
6. Add touch selection, context command, drag selection, camera gestures and hotkey groups through normal input events. Validate against classic/HD visual references and actual Simulator screenshots as required by AGENTS.md.

If single-process Steam compatibility is the dominant failure, compare a full Windows guest in UTM 5.0.5, which preserves guest process isolation. Evaluate hardware virtualization only on a documented compatible device/OS; never extrapolate that result to current iPadOS. If only software CPU emulation is available, benchmark it before adopting a full guest as the product architecture.

## Steam-owner flow being tested

Install the compatibility app, enable the documented local execution prerequisites, sign into the genuine Windows Steam client within it, install the user's purchased DE, and launch with an AgePad touch overlay. This avoids requiring a publisher ownership API key because Steam itself performs the normal purchase/account flow. It is a target flow, not a working implementation. No successful DE gameplay or multiplayer was produced by this research.
