# AgePad product viability reassessment

Follow-up: [Simulator compatibility architecture audit](SIMULATOR-ARCHITECTURE-AUDIT.md) adds executed source probes and is the current engineering priority. The immediate objective is reliable Simulator gameplay; the device-first sequencing recommended below is deferred.

**AgePad has made substantial compatibility progress, but it has not established an architecture that delivers a downloadable, reliably playable iPad product.** The main failure is the order of validation: component fixes and Simulator demonstrations have accumulated while executable installation, device execution, Steam services and reproducibility remain unresolved. More iterations of the same kind do not establish that those boundaries will eventually work.

The best remaining local-execution candidate is the original ARM64 Mac DE engine. It preserves the actual game instead of requiring the recreation of its rules, AI and campaigns. This is a recommendation for a bounded feasibility investigation, not a finding that a distributable port is viable. The replacement-engine route has confirmed missing essential behavior; the Windows route introduces additional translation and JIT constraints. Neither is an established shortcut.

Evidence was assessed on September 14, 2026. Source findings below are current workspace observations; gameplay results are principally the preserved September 12 evidence. No new match, physical-device benchmark or installation was performed. The designated G5 was the only booted Simulator, and `devicectl` reported no physical devices. The existing application and saves were not changed.

## 1. The product promise and the demonstrated system differ

The desired experience is straightforward: obtain AgePad, supply a legitimately owned game if necessary, complete a understandable setup, and play Age of Empires II with reliable controls, correct graphics, sound and durable saves. Local execution additionally means the iPad runs the simulation and rendering. A computer needed once for preparation is a different dependency from a computer required throughout every session.

The current system runs the supplied original Mac game through a substantial desktop-to-UIKit compatibility layer inside Simulator. Its recovery script requires a pre-existing private package, a booted Simulator and host Steam. It injects libraries from build folders, launches an external helper, queries host GPU metadata and starts the game using `simctl`. This is a useful laboratory setup, but none of those steps is an ordinary iPad installation flow. [L1–L4]

| Product requirement | Evidence available | Assessment |
| --- | --- | --- |
| Download and install | Simulator staging and launch scripts | No verified user-facing device package |
| Supply owned game | Private Mac game staging, hashes and case normalization | No finished importer; executable preparation remains distinct from asset import |
| Start without engineering tools | Recovery script requires private paths, helpers and host services | Not demonstrated |
| Authentic simulation | Original DE construction, production, orders and autosave load recorded | Meaningful progress, incomplete end-to-end acceptance |
| Correct graphics | World, buildings, fog and HUD; selected unit bodies absent | Release blocker |
| Reliable RTS controls | Some taps and shortcut commands work; box selection fails | Release blocker |
| Sound | Audio output initializes and starts after bridge | Audible music/effects unconfirmed |
| Durable saves | Existing autosave loads | Named-save entry and full device lifecycle unqualified |
| Sustained performance | Brief Simulator composition counts | No target-device frame-time, memory or thermal qualification |
| Multiplayer | No completed interoperability match | Unsupported claim at present |

These gaps cannot be reduced to “the UI needs polish.” Several determine whether the product can exist in its intended form. [L1–L5]

## 2. Where the approach went wrong

### A replacement engine was treated too much like a port

The freeaoe route made real progress with graphics, controls, isolated mechanics and tutorial behavior. However, loading original assets does not provide the original simulation. The upstream project explicitly describes itself as early development and its AI support as partial. [E1]

The local audit reinforces that distinction. A search of the inspected gameplay integration files finds no `AiPlayer`, `AiScript` or `ScriptLoader` references. The reference `AiScript::update` includes an unfinished rule-execution comment and a timer branch that continues without advancing its iterator. That branch would fail to make progress if reached with the stated condition; this report does not claim a new live-game reproduction. Earlier El Cid evidence records unsupported `AIScriptGoal`, `LockGate` and `UnlockGate` behavior. [L6–L7]

Completing that route means developing and validating a substantial RTS engine: AI, campaign semantics, civilization effects, pathfinding, state persistence and more. A successful tutorial and hundreds of focused checks cannot certify that workload. It should be preserved as research, not presented as the likely near-term full-game fallback.

### Simulator success was allowed to stand too close to product feasibility

An ARM64 Mac binary and an ARM64 iPad CPU share an instruction architecture. They do not share the complete operating-system environment. AppKit, desktop process discovery, filesystem layout, code signing, GPU capabilities and lifecycle remain separate compatibility problems.

`prepare-de-load-image.py` modifies Mach-O metadata and paths and ad-hoc signs the output. Its accepted platform choices are `macos` and `ios-simulator`; it explicitly does not claim to make the image compatible with iPadOS. The current original-Mac route therefore has a missing device packaging/execution step. Historical Windows-route iPhoneOS builds do not close this gap for the Mac candidate. [L3, L8]

Apple requires signed executable code and validates linked dynamic libraries. The concrete implication is that an imported desktop executable is not equivalent to an imported texture or save file. The executable, its dependencies, their signatures and their loading arrangement all require a viable device deployment design. [E2]

### The progress loop rewarded nearby fixes more than decisive answers

The history shows repeated legitimate improvements to menu input, texture handling, controls and diagnostics. It also shows major viability gates remaining open across those iterations. A technically successful next patch can still have little effect on the probability of delivering the product.

A better priority measure is: **does this experiment resolve an assumption that could invalidate the route?** Device launch and the service model have that property. Another decorative control improvement does not. Resolving invisible units is also worthwhile because it identifies whether the current world-rendering demonstration extends to essential animated content.

The problem is not evidence that an AI model can never finish the project. It is that the current workflow does not force a decision when progress on local symptoms leaves product feasibility unchanged. There is no defensible completion date in this evidence.

### Reproducibility has fallen behind experimentation

The repository currently has one commit and only three tracked planning files, all marked deleted in the working tree. The implementation directories, scripts, tests and newer documents are untracked. Some active compatibility source and rebuild commands are inside ignored `generated/mac-de-simulator-375`, including AppKit/CoreGraphics source, input tracing and saved JSON build commands. The recovery script consumes its prebuilt libraries. [L2, L9]

This does not mean the implementation has disappeared or that all generated source is unique. It means the current Git checkout is not a reproducible representation of the demonstrated candidate. A clean-clone build cannot recreate this working tree as it stands. The practical risks are losing a successful fix, testing the wrong binary and making a change that cannot be reliably rolled back.

Extract and review the project-owned source and generators needed for the candidate. Keep original game files and private binaries excluded. Record one reproducible candidate manifest and build entry point. Do not blindly add the generated tree to Git.

## 3. The Steam dependency is more fundamental than the setup text suggests

The current relay is a **local discovery bridge**, not a general network Steam service. `HostSteamPathRelay.c` listens on an `AF_UNIX` socket. `HostSteamPathQuery.h` queries the host's `com.valvesoftware.steam.ipctool` Mach service and returns a fixed-size response containing process/path information. The runner starts an `ipcserver-simulator` helper and makes that discovery available inside Simulator. [L4]

A physical iPad cannot use a Mac filesystem path or local process identity as if they belonged to its own operating system. Putting that response behind a network connection would not transport the complete Steam client, its filesystem or its IPC relationships. Valve documents Steamworks initialization as finding a running Steam client and accessing its services through RPC/IPC; merely copying the small API library is insufficient. [E3]

This leaves three questions to answer experimentally and through the applicable service/distribution terms:

1. Can this exact original game legitimately run in the desired offline configuration on a device, including a cold start, without the host discovery arrangement?
2. If a live companion is necessary, what actual services must cross the device boundary, and is there a supported, maintainable way to provide them?
3. If neither works, is publisher-supported integration available? There is no evidence of such an agreement in the project.

No recommendation here assumes fabricated authentication, account-state substitution or removal of ownership checks. A successful development session on a signed-in Mac does not answer the shipping-service question.

There is a separate multiplayer scope issue. Feral's current product page describes multiplayer with other macOS players. Existing Steam owners receive the Mac version according to the publisher's announcement, but that does not establish Windows cross-play. A Mac-based AgePad route must be tested against the corresponding retail Mac game and described accordingly. [E4–E5]

## 4. The importer must distinguish executable preparation from game data

The intended setup documents currently put “install wrapper” before “transfer prepared installation.” That can describe data transfer, but it leaves executable installation unresolved. If the device package must contain a transformed and appropriately signed copy of the privately supplied original engine, that preparation belongs before package installation. A generic app that later imports arbitrary native executable code is a different and unproven design.

Apple's review rules separately cover self-contained applications, downloaded executable code and emulator exceptions. The existence of an emulator category does not automatically qualify this native compatibility architecture. The appropriate conclusion is that distribution eligibility is unestablished, not that all emulators are forbidden or that App Store rejection is certain. [E6]

For the current original-engine experiment, a coherent conditional flow is:

1. A Mac preparation tool identifies the owned Mac edition and supported build, then validates required source files without changing the source installation.
2. It prepares the engine and compatibility package under a proven signing/install method. It prepares assets separately, with a versioned manifest. Until that method is demonstrated, this step remains a development requirement.
3. The user installs the resulting device package. Persistent asset import reports required space, progress, missing files and version compatibility. Interrupted transfers resume or roll back safely.
4. A service preflight verifies the actually supported startup configuration and explains any ongoing computer dependency before presenting Play.
5. The game starts into a usable menu, supports a complete single-player session and saves to persistent application storage.
6. A later app update preserves imported data and saves, validates compatibility, and can recover from a failed update.

Today, adjacent Simulator staging is outside this durable design: `simctl install` changes the bundle container, requiring reconstruction of sibling game-data/framework directories. A release must not rely on those siblings surviving. [L5]

If the only viable result requires each person to prepare/sign a private executable package on a computer, the product should be described as a technical installation workflow. It does not meet the same promise as downloading a universal app and importing data.

## 5. Invisible units: what is known and the next useful experiment

The preserved screenshot visibly shows a selected villager's ground ring and health bar without its body. Its HUD portrait remains present. Prior movement observations show the ring changing position after an order. Thus selection/simulation state exists while the corresponding world visual is missing. [L10]

The saved parser summary records 400 original SLD parser calls, zero failures and only two villager animation entries, both death animations. It records no idle/walk parses. This makes animation selection, request generation, cache lookup and loading a stronger immediate lead than another speculative shader patch. It does not prove that those assets were never loaded elsewhere or that GPU rendering is faultless. [L10]

The previous native Mac control did not reach gameplay under automation. That is an experimental gap, not a native rendering failure. The next comparison needs the same original game version, save, visual settings and selected unit on the Mac and Simulator. Establish the native control first, even if entering the scenario requires a manual action.

Trace the same unit through this sequence:

`unit state → selected graphic/animation ID → shape/cache request → resolved asset → parser result → atlas/upload → draw submission → visible pixels`

The first divergence determines the repair:

| First divergence | Investigation |
| --- | --- |
| No animation request | Unit graphic state, animation choice, quality/load gates and update scheduling |
| Request but wrong/missing resolution | Case normalization, mount/path translation, selected content profile and cache keys |
| Successful resolution but no parsed content | Cache behavior, async completion, parser/shape-loader boundary |
| Parsed content but no valid atlas | Upload ordering, texture views, channel semantics and resource lifetime |
| Valid atlas but no visible draw | Draw parameters, transforms, alpha/blending, visibility and pipeline state |

An acceptable fix renders idle, walk, work, attack and death animations across several units in a cold load and a save reload, alongside the original reference. One visible frame is insufficient. Resource budgets should be measured, not increased speculatively to make a branch disappear.

## 6. Graphics and performance may improve, but the current measurements cannot predict it

There is a significant favorable finding: **the Simulator GPU profile is not the physical M4 iPad GPU profile.** Apple documents restricted Simulator Metal capabilities. Its feature tables identify M4 as Apple9, with BC texture support; some earlier Apple7/8 iPadOS devices vary and require a runtime query. The name “iPad Air M4” in Simulator does not make its reported capabilities identical to that hardware. [E7–E8]

The active adapter enables software BC decoding and an experimental BC capability profile. Its texture allocation hook selects decoded backing whenever the software flag is enabled, rather than first preferring actual hardware BC support. The current mapping includes BC1 to RGBA8, BC4 to R16Float, BC5 to RG16Float and BC6 to RGBA16Float. These are deliberate compatibility paths with restrictions, not a general Metal implementation. [L11]

For illustration, a 2048×2048 BC1 texture requires about 2 MiB of compressed texels versus 16 MiB for RGBA8, before mipmaps and allocation overhead: an 8× increase. BC7-to-RGBA8 is 4×. The all-formats BC4-to-R16Float mapping is 4×. These are format-size calculations, not measured resident-memory usage for AgePad. Extra buffers and decode passes may add cost; actual residency and upload frequency need profiling.

This means targeting suitable hardware could remove substantial conversion work. It does not prove that the engine will load, fit the process memory budget or meet frame-time targets. Nor does it imply the missing units are caused by decoding. Keep native texture support and validated fallback support as separate capability paths.

The recorded approximately 23–30 composition completions per second are Simulator observations. The 51 seconds of game-clock advancement over 30 wall seconds is consistent with the displayed Normal 1.7× speed. It demonstrates timing in that short scenario, not sustained full-game performance. Comparisons made with different diagnostics or another game running are not controlled benchmarks. [L1, L12]

Proposed initial acceptance targets—not existing results—are:

- A named physical device, OS version, game build, resolution and quality preset.
- A stable 30 FPS baseline, with 95th-percentile frame time at or below 33.3 ms over representative gameplay segments; report 99th percentile and long hitches separately. Treat 60 FPS as a stretch target until measured.
- Simulation progression matching the selected speed without accumulating delay during economy and combat workloads.
- A 60-minute session covering early economy, a developed settlement, a substantial battle, save/load and background/resume, without crash or device memory termination.
- Peak memory, thermal state, command latency and loading time recorded alongside frame times. Loading/save pauses must be reported separately, not hidden from results.

Select the first hardware target from available devices and real capability results; a BC-capable M-series iPad is a sensible hypothesis, not a purchase recommendation or declared minimum specification.

## 7. Input and lifecycle need contracts, not more shortcut patches

The input chain crosses UIKit gestures, synthetic AppKit events, original Feral input translation and game commands. The existing record demonstrates a pointer-state ordering bug that was corrected without fixing box selection. Disabling delayed primary touch also did not fix box selection. This narrows the remaining work toward the consumed event sequence and translation semantics. [L12–L13]

Validate the full stream: down at the start position, movement while the primary button is logically held, ordered drag events, up at the endpoint, and cancellation that releases every held state. Observe both the adapter output and what the original engine consumes. Include drag timing and coordinate spaces. A log saying that a `mouseDragged` handler ran is not enough if button state or the subsequent translation is wrong.

Two-finger pan and pinch also require actual multi-contact testing. The existing gesture code synthesizes scroll mode with a slash key and turns pinch changes into wheel input. Those mechanisms need confirmation against the shipped configuration and touch behavior. Shortcut buttons can assist access, but they cannot certify the gestures they approximate.

The sound bridge addresses a specific unavailable Mac-default output component, and initialization/start now succeeds. Confirm actual samples and audible effects, then interruption and resume. A paused autosave load similarly does not establish named-save creation, app suspension, force-quit recovery or update survival. [L10]

Preserve the original artwork and the requested game-styled controls once interaction is reliable. The evidence does not call for a visual redesign as the first repair.

## 8. Route comparison

| Route | Principal advantage | Decisive unresolved cost | Recommendation |
| --- | --- | --- | --- |
| Original ARM64 Mac DE | Actual game rules/content; original renderer; no inherent x86 translation requirement | Device loading/signing, desktop services, graphics/input compatibility, release model | Leading bounded local-play experiment |
| Windows DE through Madeira/Wine/FEX/DXMT | Original Windows game and potentially its ecosystem | Translation, JIT setup, runtime compatibility, Steam and packaging | Park unless Mac-specific blockers or Windows interoperability justify reopening |
| freeaoe with owned classic/HD assets | Modifiable native source and reusable platform work | Missing essential engine behavior and parity validation | Preserve; do not sell as near-complete AoE II |
| Computer streaming to iPad | Existing full game renders on its supported computer | Always-on host/network, latency and tablet controls | Most established immediate way to play on iPad; changes the local-execution requirement |
| Publisher-supported native port | Can address runtime, service and redistribution design together | Agreement, access and commercial scope not established | Strategic possibility, not an available implementation dependency |

Madeira's own README calls it a research project and describes debugger-enabled JIT and sideloading. Its successful games are not proof of Age of Empires II compatibility. The Mac ARM64 route should not inherit a blanket claim that it requires x86 JIT; its blockers need to be evaluated separately. [E9]

Valve's Steam Link documents the established alternative of connecting an iPad to a computer running Steam. This can satisfy “play on my iPad,” but not “the game runs locally without my computer.” It should be offered transparently if immediate play matters, rather than silently redefining AgePad. [E10]

## 9. A decision-producing recovery plan

**First, freeze a recoverable baseline.** Extract the project-owned source needed to regenerate the current candidate, inventory all injected libraries, record original game/version hashes privately, and establish one build manifest. Preserve saves and the single-Simulator constraint. Demonstrate a rebuild from an isolated clean working directory using declared private inputs.

**Second, investigate executable deployment and services before more feature work.** Produce a device-target dependency map and exact signing/package design for the original Mac engine. Identify every host-only file, process and service. A small UIKit/device probe is useful but cannot substitute for loading the original engine. When hardware and signing are available, install and launch that engine without host filesystem access. Record the first unresolved boundary rather than declaring a generic device success.

**Third, finish the native-versus-Simulator unit comparison.** Find the first animation-path divergence and make the smallest substantiated repair. Do not reopen unrelated decoder, budget or UI experiments without evidence. Preserve this as a reproducible regression scenario.

**Fourth, prove one complete ordinary session.** Starting from a cold launch, reach a match, select and command units, gather, build, train, fight, save, quit, relaunch and load. Then exercise background/resume and an actual multi-touch camera/selection workload. Use original visuals as the reference.

**Fifth, qualify the product flow on hardware.** A fresh installation, supported owned-game preparation, persistent import, service preflight and completed session must work without shell commands during play. Measure the representative performance workloads. Finally test an update preserving assets and saves. Multiplayer gets a separate retail-client match gate.

These stages are evidence requirements, not a schedule estimate. Each experiment should record a hypothesis, a fixed candidate, a bounded run, an observation and the decision it changes. If several successive fixes leave the same product gate unanswered, require a route review rather than automatically continuing the patch sequence.

The stopping criteria are concrete:

- If the original engine cannot be deployed and launched under the intended installation model, do not build a consumer importer around that assumption.
- If Steam needs an unsupported or unmaintainable service arrangement, stop describing the route as standalone.
- If supported target hardware cannot meet the declared workload and memory budget after measured bottleneck work, reduce the supported configuration explicitly or reject the route.
- If the surviving setup requires persistent developer tooling, classify it as a research/sideloading project rather than a general download-and-play release.

The project has not proved impossibility. It has also not earned confidence that further incremental fixes will converge. The next milestone should settle the deployment and service architecture, with the invisible-unit comparison as the highest-value rendering experiment. That is the evidence needed to decide whether to invest in a polished local product.

## Sources

External sources were accessed September 14, 2026. Links identify primary sources; hardware and release conclusions above remain subject to the exact device, game build and distribution configuration.

- **E1:** sandsmark/freeaoe, [README](https://github.com/sandsmark/freeaoe/blob/master/README.md), current upstream project status. Local pinned source findings are identified separately.
- **E2:** Apple Platform Security, [App code signing process](https://support.apple.com/en-ca/guide/security/sec7c917bf14/web), mandatory signing and library validation.
- **E3:** Valve, [Steamworks API Overview](https://partner.steamgames.com/doc/sdk/api), client initialization and service architecture.
- **E4:** Feral Interactive, [Age of Empires II Mac features](https://proxies.feralinteractive.com/en/games/ageofempires2/mac/features/), macOS multiplayer scope. The FAQ index was accessible but did not expose its expanded answers, so it is not the basis for the cross-play finding.
- **E5:** Age of Empires Support, [Age of Empires II: Definitive Edition coming to Mac](https://support.ageofempires.com/hc/en-us/articles/360050470032-Age-of-Empires-II-Definitive-Edition-coming-to-Mac), existing Steam-owner access.
- **E6:** Apple Developer, [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), sections 2.5 and 4.7. No review outcome or redistribution permission has been obtained.
- **E7:** Apple Developer, [Developing Metal apps that run in Simulator](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator), Simulator capability distinction.
- **E8:** Apple Developer, [Metal Feature Set Tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf), May 21, 2026, pages 2–6: M4 family, BC support and runtime-query qualification.
- **E9:** willfaust/Madeira, [README](https://github.com/willfaust/Madeira), current research status and JIT/distribution requirements.
- **E10:** Valve, [Steam Remote Play](https://store.steampowered.com/streaming/?l=english) and [Apple Steam Link App](https://help.steampowered.com/en/faqs/view/4C03-C8BA-3EA1-B26A), host-computer streaming flow.

Local evidence is private workspace material, not an independently published release certification:

- **L1:** [README](../../README.md) and [release readiness](../RELEASE-READINESS.md), latest product and gameplay qualification.
- **L2:** [Recovery script](../../scripts/recover-de-session.py), private package and injected-library requirements.
- **L3:** [Mach-O preparation](../../scripts/prepare-de-load-image.py), supported platform choices and signing operation.
- **L4:** [Game relay runner](../../scripts/run-de-game-relay.py), [host relay](../../port/de/HostSteamPathRelay.c), [host query](../../port/de/HostSteamPathQuery.h), and [transport](../../port/de/SteamPathRelay.h).
- **L5:** [Install/online plan](../DE-INSTALL-AND-ONLINE-PLAN.md) and [adjacent staging script](../../scripts/stage-de-simulator-adjacent.py).
- **L6:** [Earlier route reassessment](../ROUTE-REASSESSMENT.md), campaign and engine-integration evidence.
- **L7:** Private `ref/freeaoe/src/ai/AiScript.cpp`, plus inspected `Engine.cpp`, `main.cpp` and `src/mechanics` integration search. The current patch contains no matching AI integration changes found by the corresponding symbol search.
- **L8:** [Windows physical-device route review](DEVICE-EXECUTION-ROUTE.md), separate build-only evidence and device limits.
- **L9:** Workspace `git status`, `git ls-files` and `git log`; [.gitignore](../../.gitignore); private `generated/mac-de-simulator-375/rebuild-and-run.py` and source/build-command inventory.
- **L10:** Private `generated/render-audio-20260912/REPORT.md`, `sld-results.json` and `status-fixed-villager-missing.png`; screenshot inspected and parser summary read for this assessment.
- **L11:** [Metal device adapter](../../port/de/MetalDevicesCompat.m), [format mappings](../../port/de/BCFormat.h) and [texture upload adapter](../../port/de/BC4TextureCompat.m).
- **L12:** [Reorientation journal](../MADEIRA-REORIENTATION.md), September 12 timing and input experiments.
- **L13:** [Native touch gestures](../../port/de/NativeTouchGestures.m), synthetic gesture event behavior.
